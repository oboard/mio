///|
#cfg(target="native")
priv suberror Http3CodecError {
  Http3FrameTruncated
} derive(Debug, ToJson)

///|
#cfg(target="native")
let h3_frame_headers : Int = 0x1

///|
#cfg(target="native")
priv struct H3Frame {
  frame_type : Int
  payload : Bytes
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
#warnings("-unused_value")
fn h3_decode_frame(data : Bytes, offset? : Int = 0) -> H3Frame raise {
  let (frame_type, pos) = quic_read_varint(data, offset)
  let (len, pos) = quic_read_varint(data, pos)
  guard pos + len <= data.length() else { raise Http3FrameTruncated }
  let payload = @buffer.new()
  payload.write_bytes(data[pos:pos + len])
  { frame_type, payload: payload.contents() }
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
fn h3_perform_request(
  _uri : String,
  _meth : RequestMethod,
  _headers : Map[String, String],
  _body : &@io.Data,
) -> ResponseBody raise {
  raise Http3RequiresQuic
}
