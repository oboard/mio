///|
#cfg(target="native")
priv enum BodyKind {
  Empty
  Fixed(Int)
  Chunked(Int)
  Decoded(Bytes, Int)
  PassThrough
  WaitConnectionClose
}

///|
#cfg(target="native")
priv enum ContentDecoder {
  Gzip
  Deflate
  Brotli
  Zstd
}

///|
#cfg(target="native")
#warnings("-alert_internal")
priv struct Reader {
  /// A HTTP reader type that can parse and deliver HTTP request/response
  mut body : BodyKind
  transport : &@io.Reader
  read_buf : @io.ReaderBuffer
  mut auto_decompress : Bool
  mut decoder : ContentDecoder?
}

///|
#cfg(target="native")
#warnings("-alert_internal")
priv struct BytesReader {
  data : Bytes
  mut offset : Int
  read_buf : @io.ReaderBuffer
}

///|
#cfg(target="native")
#warnings("-alert_internal")
fn BytesReader::new(data : Bytes) -> BytesReader {
  { data, offset: 0, read_buf: @io.ReaderBuffer::new() }
}

///|
#cfg(target="native")
impl @io.Reader for BytesReader with _direct_read(self, dst, offset~, max_len~) {
  let remaining = self.data.length() - self.offset
  let len = @cmp.minimum(max_len, remaining)
  if len > 0 {
    dst.blit_from_bytes(offset, self.data, self.offset, len)
    self.offset += len
  }
  len
}

///|
#cfg(target="native")
#warnings("-alert_internal")
impl @io.Reader for BytesReader with _get_internal_buffer(self) {
  self.read_buf
}

///|
#cfg(target="native")
#warnings("-alert_internal")
/// Create a new HTTP reader wrapping around existing reader `transport`.
/// The HTTP reader will read data from `transport`.
fn[R : @io.Reader] Reader::new(transport : R) -> Reader {
  {
    body: Empty,
    transport,
    read_buf: @io.ReaderBuffer::new(),
    auto_decompress: false,
    decoder: None,
  }
}

///|
#cfg(target="native")
pub suberror HttpProtocolError {
  BadRequest
  HttpVersionNotSupported(String)
  NotImplemented
} derive(Debug, ToJson)

///|
#cfg(target="native")
async fn decode_gzip(data : Bytes) -> Bytes {
  let reader = BytesReader::new(data)
  @gzip.Decoder::new(reader).read_all().binary() catch {
    _ => raise BadRequest
  }
}

///|
#cfg(target="native")
async fn ContentDecoder::decode(self : ContentDecoder, data : Bytes) -> Bytes {
  match self {
    Gzip => decode_gzip(data)
    Deflate => @flate.decompress(data) catch { _ => raise BadRequest }
    Brotli => @brotli.decompress(data) catch { _ => raise BadRequest }
    Zstd => @zstd.decompress(data) catch { _ => raise BadRequest }
  }
}

///|
#cfg(target="native")
async fn Reader::read_encoded_body(self : Reader) -> Bytes {
  let output = @buffer.new()
  match self.body {
    Empty => ()
    Fixed(remaining) =>
      if remaining > 0 {
        output.write_bytes(self.transport.read_exactly(remaining))
      }
    Chunked(curr_chunk_remaining) =>
      for remaining = curr_chunk_remaining {
        if remaining > 0 {
          output.write_bytes(self.transport.read_exactly(remaining))
          guard self.transport.read_exactly(2) == b"\r\n" else {
            raise BadRequest
          }
          continue 0
        }
        guard self.transport.read_until("\r\n") is Some(len_str) else {
          raise @io.ReaderClosed
        }
        let next_chunk_len = @string.parse_int(len_str, base=16) catch {
          _ => raise BadRequest
        }
        if next_chunk_len == 0 {
          guard self.transport.read_exactly(2) == b"\r\n" else {
            raise BadRequest
          }
          break
        }
        guard next_chunk_len > 0 else { raise BadRequest }
        continue next_chunk_len
      }
    Decoded(data, offset) => output.write_bytes(data[offset:])
    WaitConnectionClose => {
      let buf = FixedArray::make(4096, b'\x00')
      for ;; {
        let n = self.transport.read(buf)
        if n == 0 {
          break
        }
        output.write_bytes(buf.unsafe_reinterpret_as_bytes()[:n])
      }
    }
    PassThrough => raise BadRequest
  }
  self.body = Empty
  output.contents()
}

///|
#cfg(target="native")
async fn Reader::ensure_decoded(self : Reader) -> Unit {
  if self.body is Decoded(_) || self.decoder is None {
    return
  }
  guard self.decoder is Some(decoder)
  let encoded = self.read_encoded_body()
  let decoded = decoder.decode(encoded)
  self.decoder = None
  self.body = Decoded(decoded, 0)
}

///|
#cfg(target="native")
/// Read from the body of the HTTP request/response
/// that is currently being processed by the HTTP reader.
/// All reader related API of `HttpReader` should be called
/// after a successful call to `read_response`,
/// otherwise reading always result in EOF.
impl @io.Reader for Reader with _direct_read(self, buf, offset~, max_len~) {
  self.ensure_decoded()
  match self.body {
    Empty => 0
    Decoded(data, pos) => {
      let len = @cmp.minimum(max_len, data.length() - pos)
      if len > 0 {
        buf.blit_from_bytes(offset, data, pos, len)
      }
      self.body = if pos + len == data.length() {
        Empty
      } else {
        Decoded(data, pos + len)
      }
      len
    }
    Fixed(remaining) => {
      let max_len = @cmp.minimum(max_len, remaining)
      let n = self.transport.read(buf, offset~, max_len~)
      let remaining = remaining - n
      self.body = if remaining == 0 { Empty } else { Fixed(remaining) }
      n
    }
    Chunked(0) => {
      guard self.transport.read_until("\r\n") is Some(len_str) else {
        raise @io.ReaderClosed
      }
      let next_chunk_len = @string.parse_int(len_str, base=16) catch {
        _ => raise BadRequest
      }
      guard next_chunk_len > 0 else {
        guard self.transport.read_exactly(2) == b"\r\n" else {
          raise BadRequest
        }
        self.body = Empty
        return 0
      }
      let max_len = @cmp.minimum(max_len, next_chunk_len)
      let n = self.transport.read(buf, offset~, max_len~)
      let remaining = next_chunk_len - n
      if remaining == 0 {
        guard self.transport.read_exactly(2) == b"\r\n" else {
          raise BadRequest
        }
      }
      self.body = Chunked(remaining)
      if n == 0 {
        self._direct_read(buf, offset~, max_len~)
      } else {
        n
      }
    }
    Chunked(curr_chunk_remaining) => {
      let max_len = @cmp.minimum(max_len, curr_chunk_remaining)
      let n = self.transport.read(buf, offset~, max_len~)
      let remaining = curr_chunk_remaining - n
      if remaining == 0 {
        guard self.transport.read_exactly(2) == b"\r\n" else {
          raise BadRequest
        }
      }
      self.body = Chunked(remaining)
      if n == 0 {
        self._direct_read(buf, offset~, max_len~)
      } else {
        n
      }
    }
    PassThrough => self.transport._direct_read(buf, offset~, max_len~)
    WaitConnectionClose => self.transport._direct_read(buf, offset~, max_len~)
  }
}

///|
#cfg(target="native")
#warnings("-alert_internal")
impl @io.Reader for Reader with _get_internal_buffer(self) {
  if self.body is PassThrough || self.body is WaitConnectionClose {
    self.transport._get_internal_buffer()
  } else {
    self.read_buf
  }
}

///|
#cfg(target="native")
async fn Reader::read_headers(
  self : Reader,
) -> (Map[String, String], Array[Cookie]) {
  let headers = {}
  let cookies = []
  for ;; {
    guard self.transport.read_until("\r\n") is Some(header_line) else {
      raise @io.ReaderClosed
    }
    if header_line is "" {
      // empty line indicates end of header
      break
    }
    guard header_line.find(":") is Some(colon_index) else { raise BadRequest }
    let key = header_line[:colon_index].to_lower().to_owned()
    guard colon_index + 1 < header_line.length() else { raise BadRequest }
    let value_start = if header_line.code_unit_at(colon_index + 1) == ' ' {
      colon_index + 2
    } else {
      colon_index + 1
    }
    let value = header_line[value_start:].to_owned()
    match key {
      "content-length" => {
        guard !(self.body is Fixed(_)) else { raise BadRequest }
        let len = @string.parse_int(value, base=10)
        if self.body is Empty && len > 0 {
          self.body = Fixed(len)
        }
        // if automatic decompression is enabled, avoid reporting a wrong content-length value
        if self.decoder is Some(_) {
          continue
        }
      }
      "transfer-encoding" => {
        guard !(self.body is Chunked(_)) else { raise BadRequest }
        guard value.to_lower() is "chunked" else { raise NotImplemented }
        self.body = Chunked(0)
      }
      "content-encoding" if self.auto_decompress => {
        guard self.decoder is None else { raise BadRequest }
        let decoder = match value.trim().to_lower() {
          "gzip" => Some(Gzip)
          "deflate" => Some(Deflate)
          "br" => Some(Brotli)
          "zstd" => Some(Zstd)
          "identity" => None
          _ => raise NotImplemented
        }
        if decoder is Some(_) {
          self.decoder = decoder
          // if automatic decompression is enabled, avoid reporting a wrong content-length value
          headers.remove("content-length")
          continue
        }
      }
      "set-cookie" => {
        cookies.push(Cookie::parse(value))
        continue
      }
      _ => ()
    }
    match headers.get(key) {
      None => headers[key] = value
      Some(value0) => headers[key] = "\{value0},\{value}"
    }
  }
  (headers, cookies)
}

///|
#cfg(target="native")
/// Determines if the response body should be read until connection close.
/// Returns true when:
/// - No Content-Length or Transfer-Encoding header is present
/// - Body has not been determined by other means (still Empty)
/// - Status code is not 1xx, 204, 205, or 304 (which MUST NOT have a message body)
/// - Not a successful (2xx) response to a CONNECT request (which becomes a tunnel)
/// - Not a response to a HEAD request (which never has a message body)
#warnings("-unused_value")
fn should_read_body_until_close(
  code : Int,
  headers : Map[String, String],
  current_body : BodyKind,
  request_method : RequestMethod?,
) -> Bool {
  if response_must_be_bodyless(code, request_method) {
    return false
  }
  current_body is Empty &&
  headers.get("content-length") is None &&
  headers.get("transfer-encoding") is None &&
  code >= 200
}

///|
#cfg(target="native")
fn response_must_be_bodyless(
  code : Int,
  request_method : RequestMethod?,
) -> Bool {
  request_method is Some(Head) ||
  (request_method is Some(Connect) && code >= 200 && code < 300) ||
  code < 200 ||
  code == 204 ||
  code == 205 ||
  code == 304
}

///|
#cfg(target="native")
/// Read the header of a HTTP/1.1 response from a HTTP reader.
/// This function must be called after the body of the last response is consumed,
/// otherwise it will abort the program immediately.
/// If the body is not needed, use `HttpReader::skip_body` to discard it.
///
/// After `read_response` successfully returned,
/// the HTTP reader itself can be used to extract the body of the response.
///
/// HTTP header fields are case insensitive.
/// In the result of `read_response`, all header fields will be in lower case.
async fn Reader::read_response(
  self : Reader,
  auto_decompress~ : Bool,
  request_method~ : RequestMethod?,
) -> Response {
  self.auto_decompress = auto_decompress
  guard self.body is Empty
  guard self.transport.read_until("\r\n") is Some(response_line) else {
    raise @io.ReaderClosed
  }
  guard response_line.find(" ") is Some(protocol_len) else { raise BadRequest }
  match response_line[:protocol_len] {
    "HTTP/1.1" | "HTTP/1.0" => ()
    protocol => raise HttpVersionNotSupported(protocol.to_owned())
  }
  let response_line = response_line[protocol_len + 1:]
  guard response_line.find(" ") is Some(code_len) else { raise BadRequest }
  let code = @string.parse_int(response_line[:code_len], base=10) catch {
    _ => raise BadRequest
  }
  let reason = response_line[code_len + 1:].to_owned()
  let (headers, cookies) = self.read_headers()

  // HTTP/1.1 Spec (RFC 7230 Section 3.3.3): Message Body Length Determination
  // Other cases are handled in `read_headers` when parsing the headers, which will set the body kind accordingly.
  let bodyless = response_must_be_bodyless(code, request_method)
  if bodyless {
    self.body = Empty
  } else if self.body is Empty &&
    headers.get("content-length") is None &&
    headers.get("transfer-encoding") is None &&
    code >= 200 {
    self.body = WaitConnectionClose // Read until connection close
  }

  { code, reason, headers, cookies }
}

///|
#cfg(target="native")
/// Discard the body of current HTTP request/response,
/// so that the next request/response can be processed.
async fn Reader::skip_body(self : Reader) -> Unit {
  if self.body is Empty {
    return
  }
  while self.drop(1024) == 1024 {

  }
}

///|
#cfg(target="native")
async fn Reader::enter_passthrough_mode(self : Reader) -> Unit {
  self.skip_body()
  self.body = PassThrough
}
