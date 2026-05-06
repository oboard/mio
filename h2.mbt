///|
#cfg(target="native")
pub suberror Http2Error {
  Http2BadFrame
  Http2ConnectionError(String)
  Http2StreamReset(Int)
  Http2MissingStatus
} derive(Debug, ToJson)

///|
#cfg(target="native")
let h2_frame_data : Int = 0

///|
#cfg(target="native")
let h2_frame_headers : Int = 1

///|
#cfg(target="native")
let h2_frame_rst_stream : Int = 3

///|
#cfg(target="native")
let h2_frame_settings : Int = 4

///|
#cfg(target="native")
let h2_frame_ping : Int = 6

///|
#cfg(target="native")
let h2_frame_goaway : Int = 7

///|
#cfg(target="native")
let h2_frame_window_update : Int = 8

///|
#cfg(target="native")
let h2_frame_continuation : Int = 9

///|
#cfg(target="native")
let h2_default_max_frame_size : Int = 16384

///|
#cfg(target="native")
let h2_flag_end_stream : Int = 0x1

///|
#cfg(target="native")
let h2_flag_ack : Int = 0x1

///|
#cfg(target="native")
let h2_flag_end_headers : Int = 0x4

///|
#cfg(target="native")
let h2_preface : Bytes = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

///|
#cfg(target="native")
priv struct H2Frame {
  frame_type : Int
  flags : Int
  stream_id : Int
  payload : Bytes
}

///|
#cfg(target="native")
fn h2_write_u24(out : @buffer.Buffer, value : Int) -> Unit {
  out.write_byte(((value >> 16) & 0xff).to_byte())
  out.write_byte(((value >> 8) & 0xff).to_byte())
  out.write_byte((value & 0xff).to_byte())
}

///|
#cfg(target="native")
fn h2_write_u31(out : @buffer.Buffer, value : Int) -> Unit {
  out.write_byte(((value >> 24) & 0x7f).to_byte())
  out.write_byte(((value >> 16) & 0xff).to_byte())
  out.write_byte(((value >> 8) & 0xff).to_byte())
  out.write_byte((value & 0xff).to_byte())
}

///|
#cfg(target="native")
async fn[W : @io.Writer] h2_write_frame(
  writer : W,
  frame_type : Int,
  flags : Int,
  stream_id : Int,
  payload : Bytes,
) -> Unit {
  let out = @buffer.new()
  h2_write_u24(out, payload.length())
  out.write_byte(frame_type.to_byte())
  out.write_byte(flags.to_byte())
  h2_write_u31(out, stream_id)
  out.write_bytes(payload)
  writer.write(out.contents())
}

///|
#cfg(target="native")
async fn[W : @io.Writer] h2_write_window_update(
  writer : W,
  stream_id : Int,
  increment : Int,
) -> Unit {
  guard increment > 0 else { return }
  let payload = @buffer.new()
  h2_write_u31(payload, increment)
  h2_write_frame(
    writer,
    h2_frame_window_update,
    0,
    stream_id,
    payload.contents(),
  )
}

///|
#cfg(target="native")
async fn[W : @io.Writer] h2_write_data_frames(
  writer : W,
  stream_id : Int,
  data : Bytes,
) -> Unit {
  if data.length() == 0 {
    return
  }
  for offset = 0; offset < data.length(); {
    let len = @cmp.minimum(h2_default_max_frame_size, data.length() - offset)
    let end = offset + len
    let flags = if end == data.length() { h2_flag_end_stream } else { 0 }
    let payload = @buffer.new()
    payload.write_bytes(data[offset:end])
    h2_write_frame(writer, h2_frame_data, flags, stream_id, payload.contents())
    continue end
  }
}

///|
#cfg(target="native")
async fn[R : @io.Reader] h2_read_frame(reader : R) -> H2Frame {
  let header = reader.read_exactly(9)
  let length = (header[0].to_int() << 16) |
    (header[1].to_int() << 8) |
    header[2].to_int()
  let frame_type = header[3].to_int()
  let flags = header[4].to_int()
  let stream_id = ((header[5].to_int() & 0x7f) << 24) |
    (header[6].to_int() << 16) |
    (header[7].to_int() << 8) |
    header[8].to_int()
  let payload = if length == 0 { b"" } else { reader.read_exactly(length) }
  { frame_type, flags, stream_id, payload }
}

///|
#cfg(target="native")
fn h2_validate_settings(frame : H2Frame) -> Unit raise {
  guard frame.stream_id == 0 else { raise Http2BadFrame }
  if (frame.flags & h2_flag_ack) != 0 {
    guard frame.payload.length() == 0 else { raise Http2BadFrame }
  } else {
    guard frame.payload.length() % 6 == 0 else { raise Http2BadFrame }
  }
}

///|
#cfg(target="native")
fn RequestMethod::h2_text(self : RequestMethod) -> String {
  match self {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
#cfg(target="native")
fn h2_request_headers(
  protocol : Protocol,
  host : String,
  path : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body_len : Int,
) -> Bytes {
  let header_list = []
  header_list.push((":method", meth.h2_text()))
  header_list.push(
    (
      ":scheme",
      match protocol {
        Http => "http"
        Https => "https"
      },
    ),
  )
  header_list.push((":authority", host))
  header_list.push((":path", path))
  if body_len > 0 {
    header_list.push(("content-length", body_len.to_string()))
  }
  let mut has_accept_encoding = false
  for item in headers {
    let (key, value) = item
    let key = key.to_lower()
    match key {
      "connection"
      | "host"
      | "keep-alive"
      | "proxy-connection"
      | "transfer-encoding"
      | "upgrade" => ()
      "accept-encoding" => {
        has_accept_encoding = true
        header_list.push((key, value))
      }
      _ => header_list.push((key, value))
    }
  }
  if !has_accept_encoding {
    header_list.push(("accept-encoding", "gzip, deflate, br, zstd"))
  }
  hpack_encode_headers(header_list)
}

///|
#cfg(target="native")
fn h2_response_from_headers(
  headers : Array[(String, String)],
) -> Response raise {
  let response_headers = {}
  let cookies = []
  let mut code = -1
  for item in headers {
    let (key, value) = item
    if key == ":status" {
      code = @string.parse_int(value, base=10) catch { _ => -1 }
    } else if key == "set-cookie" {
      cookies.push(Cookie::parse(value)) catch {
        _ => ()
      }
    } else if key.has_prefix(":") {
      ()
    } else {
      match response_headers.get(key) {
        None => response_headers[key] = value
        Some(value0) => response_headers[key] = "\{value0},\{value}"
      }
    }
  }
  guard code >= 0 else { raise Http2MissingStatus }
  { code, reason: "", headers: response_headers, cookies }
}

///|
#cfg(target="native")
fn h2_decode_body(response : Response, body : Bytes) -> Bytes raise {
  match response.headers.get("content-encoding") {
    Some("gzip") => Gzip.decode(body)
    Some("deflate") => Deflate.decode(body)
    Some("br") => Brotli.decode(body)
    Some("zstd") => Zstd.decode(body)
    _ => body
  }
}

///|
#cfg(target="native")
async fn[Conn : @io.Reader + @io.Writer] h2_request_on_conn(
  conn : Conn,
  protocol : Protocol,
  host : String,
  path : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : Bytes,
) -> ResponseBody {
  conn.write(h2_preface)
  h2_write_frame(conn, h2_frame_settings, 0, 0, b"")
  let header_block = h2_request_headers(
    protocol,
    host,
    path,
    meth,
    headers,
    body.length(),
  )
  let mut flags = h2_flag_end_headers
  if body.length() == 0 {
    flags = flags | h2_flag_end_stream
  }
  h2_write_frame(conn, h2_frame_headers, flags, 1, header_block)
  h2_write_data_frames(conn, 1, body)
  let body_out = @buffer.new()
  let header_out = @buffer.new()
  let hpack_decoder = HpackDecoder::new()
  let mut response : Response? = None
  let mut end_stream = false
  for ; !end_stream; {
    let frame = h2_read_frame(conn)
    match frame.frame_type {
      t if t == h2_frame_settings => {
        h2_validate_settings(frame)
        if (frame.flags & h2_flag_ack) == 0 {
          h2_write_frame(conn, h2_frame_settings, h2_flag_ack, 0, b"")
        }
      }
      t if t == h2_frame_headers && frame.stream_id == 1 => {
        header_out.write_bytes(frame.payload)
        if (frame.flags & h2_flag_end_headers) == 0 {
          for ;; {
            let cont = h2_read_frame(conn)
            guard cont.frame_type == h2_frame_continuation &&
              cont.stream_id == 1 else {
              raise Http2BadFrame
            }
            header_out.write_bytes(cont.payload)
            if (cont.flags & h2_flag_end_headers) != 0 {
              break
            }
          }
        }
        if response is None {
          response = Some(
            h2_response_from_headers(
              hpack_decoder.decode(header_out.contents()),
            ),
          )
        } else {
          hpack_decoder.decode(header_out.contents()) |> ignore
        }
        header_out.reset()
        if (frame.flags & h2_flag_end_stream) != 0 {
          end_stream = true
        }
      }
      t if t == h2_frame_data && frame.stream_id == 1 => {
        body_out.write_bytes(frame.payload)
        h2_write_window_update(conn, 0, frame.payload.length())
        h2_write_window_update(conn, 1, frame.payload.length())
        if (frame.flags & h2_flag_end_stream) != 0 {
          end_stream = true
        }
      }
      t if t == h2_frame_rst_stream && frame.stream_id == 1 => {
        let code = if frame.payload.length() >= 4 {
          (frame.payload[0].to_int() << 24) |
          (frame.payload[1].to_int() << 16) |
          (frame.payload[2].to_int() << 8) |
          frame.payload[3].to_int()
        } else {
          -1
        }
        raise Http2StreamReset(code)
      }
      t if t == h2_frame_ping =>
        if (frame.flags & h2_flag_ack) == 0 {
          h2_write_frame(conn, h2_frame_ping, h2_flag_ack, 0, frame.payload)
        }
      t if t == h2_frame_goaway => raise Http2ConnectionError("GOAWAY")
      t if t == h2_frame_window_update => ()
      _ => ()
    }
  }
  guard response is Some(response) else { raise Http2MissingStatus }
  { response, body: h2_decode_body(response, body_out.contents()) }
}

///|
#cfg(target="native")
async fn h2_perform_request(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
  verify? : Bool = true,
) -> ResponseBody {
  let (protocol, port, host, path) = resolve_url(uri)
  guard proxy is None else {
    raise Http2ConnectionError("HTTP/2 proxy transport is not implemented")
  }
  let request_body = body.binary()
  match protocol {
    Http => {
      let conn = @socket.Tcp::connect_to_host(host, port~)
      defer conn.close()
      h2_request_on_conn(
        conn, protocol, host, path, meth, headers, request_body,
      )
    }
    Https => {
      let tcp = @socket.Tcp::connect_to_host(host, port~)
      let tls = @tls.Tls::client(tcp, host~, verify~) catch {
        err => {
          tcp.close()
          raise err
        }
      }
      defer {
        tls.close()
        tcp.close()
      }
      h2_request_on_conn(tls, protocol, host, path, meth, headers, request_body)
    }
  }
}
