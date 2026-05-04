///|
#cfg(target="native")
priv suberror Http3CodecError {
  Http3FrameTruncated
  Http3FrameUnsupported
} derive(Debug, ToJson)

///|
#cfg(target="native")
let h3_frame_data : Int = 0x0

///|
#cfg(target="native")
let h3_frame_headers : Int = 0x1

///|
#cfg(target="native")
let h3_frame_settings : Int = 0x4

///|
#cfg(target="native")
let h3_stream_control : Int = 0x0

///|
#cfg(target="native")
priv struct H3Frame {
  frame_type : Int
  payload : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct H3DecodedResponse {
  status : Int
  headers : Array[(String, String)]
  body : Bytes
}

///|
#cfg(target="native")
fn h3_encode_frame(frame_type : Int, payload : Bytes) -> Bytes raise {
  let out = @buffer.new()
  quic_write_varint(out, frame_type)
  quic_write_varint(out, payload.length())
  out.write_bytes(payload)
  out.contents()
}

///|
#cfg(target="native")
fn h3_decode_frame_at(data : Bytes, offset : Int) -> (H3Frame, Int) raise {
  let (frame_type, pos) = quic_read_varint(data, offset)
  let (len, pos) = quic_read_varint(data, pos)
  guard pos + len <= data.length() else { raise Http3FrameTruncated }
  let payload = @buffer.new()
  payload.write_bytes(data[pos:pos + len])
  ({ frame_type, payload: payload.contents() }, pos + len)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_decode_frame(data : Bytes, offset? : Int = 0) -> H3Frame raise {
  let (frame, _) = h3_decode_frame_at(data, offset)
  frame
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_decode_frames(data : Bytes) -> Array[H3Frame] raise {
  let frames = []
  for offset = 0; offset < data.length(); {
    let (frame, next) = h3_decode_frame_at(data, offset)
    frames.push(frame)
    continue next
  }
  frames
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_encode_data(data : Bytes) -> Bytes raise {
  h3_encode_frame(h3_frame_data, data)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_encode_headers(headers : Array[(String, String)]) -> Bytes raise {
  h3_encode_frame(h3_frame_headers, qpack_encode_header_block(headers))
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_decode_headers(frame : H3Frame) -> Array[(String, String)] raise {
  guard frame.frame_type == h3_frame_headers else { raise Http3FrameTruncated }
  qpack_decode_header_block(frame.payload)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_encode_settings(settings : Array[(Int, Int)]) -> Bytes raise {
  let payload = @buffer.new()
  for setting in settings {
    quic_write_varint(payload, setting.0)
    quic_write_varint(payload, setting.1)
  }
  h3_encode_frame(h3_frame_settings, payload.contents())
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_decode_settings(frame : H3Frame) -> Array[(Int, Int)] raise {
  guard frame.frame_type == h3_frame_settings else {
    raise Http3FrameUnsupported
  }
  let settings = []
  for offset = 0; offset < frame.payload.length(); {
    let (identifier, pos) = quic_read_varint(frame.payload, offset)
    let (value, pos) = quic_read_varint(frame.payload, pos)
    settings.push((identifier, value))
    continue pos
  }
  settings
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_encode_control_stream(settings : Array[(Int, Int)]) -> Bytes raise {
  let out = @buffer.new()
  quic_write_varint(out, h3_stream_control)
  out.write_bytes(h3_encode_settings(settings))
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_encode_request_stream(
  headers : Array[(String, String)],
  body : Bytes,
) -> Bytes raise {
  let out = @buffer.new()
  out.write_bytes(h3_encode_headers(headers))
  if body.length() > 0 {
    out.write_bytes(h3_encode_data(body))
  }
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn h3_decode_response_stream(stream_data : Bytes) -> H3DecodedResponse raise {
  let frames = h3_decode_frames(stream_data)
  let mut status = -1
  let mut headers = []
  let body = @buffer.new()
  for frame in frames {
    if frame.frame_type == h3_frame_headers {
      headers = h3_decode_headers(frame)
      for header in headers {
        if header.0 == ":status" {
          status = @string.parse_int(header.1, base=10) catch { _ => -1 }
        }
      }
    } else if frame.frame_type == h3_frame_data {
      body.write_bytes(frame.payload)
    } else {
      raise Http3FrameUnsupported
    }
  }
  guard status >= 0 else { raise Http3FrameUnsupported }
  { status, headers, body: body.contents() }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_decode_h3_response_packets(
  packets : Array[Bytes],
  destination_connection_id_length : Int,
  keys : QuicPacketKeys,
  stream_id? : Int = 0,
) -> H3DecodedResponse raise {
  let stream_data = @buffer.new()
  for packet in packets {
    let opened = quic_open_short_packet(
      packet, destination_connection_id_length, keys,
    )
    stream_data.write_bytes(quic_collect_stream_data(opened.payload, stream_id))
  }
  h3_decode_response_stream(stream_data.contents())
}

///|
#cfg(target="native")
fn h3_perform_request(
  _uri : String,
  _meth : RequestMethod,
  _headers : Map[String, String],
  _body : &@io.Data,
) -> ResponseBody raise {
  raise Http3RequiresQuic
}
