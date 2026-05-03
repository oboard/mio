///|
#cfg(target="native")
priv suberror QuicTransportParameterError {
  QuicTransportParameterTruncated
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_value")
let quic_tp_original_destination_connection_id : Int = 0x00

///|
#cfg(target="native")
let quic_tp_max_idle_timeout : Int = 0x01

///|
#cfg(target="native")
let quic_tp_initial_max_data : Int = 0x04

///|
#cfg(target="native")
let quic_tp_initial_max_stream_data_bidi_local : Int = 0x05

///|
#cfg(target="native")
let quic_tp_initial_max_stream_data_bidi_remote : Int = 0x06

///|
#cfg(target="native")
let quic_tp_initial_max_stream_data_uni : Int = 0x07

///|
#cfg(target="native")
let quic_tp_initial_max_streams_bidi : Int = 0x08

///|
#cfg(target="native")
let quic_tp_initial_max_streams_uni : Int = 0x09

///|
#cfg(target="native")
let quic_tp_active_connection_id_limit : Int = 0x0e

///|
#cfg(target="native")
let quic_tp_initial_source_connection_id : Int = 0x0f

///|
#cfg(target="native")
let quic_tp_max_udp_payload_size : Int = 0x03

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicTransportParameter {
  identifier : Int
  value : Bytes
}

///|
#cfg(target="native")
#warnings("-struct_never_constructed")
priv struct QuicClientTransportParameters {
  initial_source_connection_id : Bytes
  max_idle_timeout : Int
  max_udp_payload_size : Int
  initial_max_data : Int
  initial_max_stream_data_bidi_local : Int
  initial_max_stream_data_bidi_remote : Int
  initial_max_stream_data_uni : Int
  initial_max_streams_bidi : Int
  initial_max_streams_uni : Int
  active_connection_id_limit : Int
}

///|
#cfg(target="native")
fn quic_encode_varint_value(value : Int) -> Bytes raise {
  let out = @buffer.new()
  quic_write_varint(out, value)
  out.contents()
}

///|
#cfg(target="native")
fn quic_write_transport_parameter(
  out : @buffer.Buffer,
  identifier : Int,
  value : Bytes,
) -> Unit raise {
  quic_write_varint(out, identifier)
  quic_write_varint(out, value.length())
  out.write_bytes(value)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_client_transport_parameters(
  params : QuicClientTransportParameters,
) -> Bytes raise {
  let out = @buffer.new()
  quic_write_transport_parameter(
    out,
    quic_tp_initial_source_connection_id,
    params.initial_source_connection_id,
  )
  quic_write_transport_parameter(
    out,
    quic_tp_max_idle_timeout,
    quic_encode_varint_value(params.max_idle_timeout),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_max_udp_payload_size,
    quic_encode_varint_value(params.max_udp_payload_size),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_data,
    quic_encode_varint_value(params.initial_max_data),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_stream_data_bidi_local,
    quic_encode_varint_value(params.initial_max_stream_data_bidi_local),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_stream_data_bidi_remote,
    quic_encode_varint_value(params.initial_max_stream_data_bidi_remote),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_stream_data_uni,
    quic_encode_varint_value(params.initial_max_stream_data_uni),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_streams_bidi,
    quic_encode_varint_value(params.initial_max_streams_bidi),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_initial_max_streams_uni,
    quic_encode_varint_value(params.initial_max_streams_uni),
  )
  quic_write_transport_parameter(
    out,
    quic_tp_active_connection_id_limit,
    quic_encode_varint_value(params.active_connection_id_limit),
  )
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_decode_transport_parameters(
  data : Bytes,
) -> Array[QuicTransportParameter] raise {
  let params = []
  for offset = 0; offset < data.length(); {
    let (identifier, pos) = quic_read_varint(data, offset)
    let (len, pos) = quic_read_varint(data, pos)
    guard pos + len <= data.length() else {
      raise QuicTransportParameterTruncated
    }
    params.push({ identifier, value: quic_copy_slice(data, pos, pos + len) })
    continue pos + len
  }
  params
}
