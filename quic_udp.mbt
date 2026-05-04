///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_client_initial(
  addr : @socket.Addr,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  crypto_data : Bytes,
) -> QuicProtectedPacket {
  let conn = @socket.UdpClient(addr)
  defer conn.close()
  let datagram = quic_build_client_initial_datagram(
    destination_connection_id, source_connection_id, 0, crypto_data,
  )
  conn.send(datagram.packet)
  datagram
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicTlsClientInitial {
  datagram : QuicProtectedPacket
  client_hello : Bytes
  client_public_key : Bytes
  transport_parameters : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_tls13_client_initial(
  addr : @socket.Addr,
  server_name : String,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  client_private_key : Bytes,
  random : Bytes,
  legacy_session_id : Bytes,
) -> QuicTlsClientInitial {
  let client_public_key = x25519_base(client_private_key)
  let transport_parameters = quic_encode_client_transport_parameters({
    initial_source_connection_id: source_connection_id,
    max_idle_timeout: 30000,
    max_udp_payload_size: 1200,
    initial_max_data: 1048576,
    initial_max_stream_data_bidi_local: 262144,
    initial_max_stream_data_bidi_remote: 262144,
    initial_max_stream_data_uni: 262144,
    initial_max_streams_bidi: 100,
    initial_max_streams_uni: 3,
    active_connection_id_limit: 2,
  })
  let client_hello = tls13_encode_client_hello({
    server_name,
    alpn: "h3",
    random,
    legacy_session_id,
    x25519_public_key: client_public_key,
    transport_parameters,
  })
  {
    datagram: quic_send_client_initial(
      addr, destination_connection_id, source_connection_id, client_hello,
    ),
    client_hello,
    client_public_key,
    transport_parameters,
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_h3_request_packet(
  destination_connection_id : Bytes,
  packet_number : Int,
  keys : QuicPacketKeys,
  stream_id : Int,
  headers : Array[(String, String)],
  body : Bytes,
) -> QuicProtectedPacket raise {
  quic_build_short_packet(
    destination_connection_id,
    packet_number,
    quic_encode_stream_frame(
      stream_id,
      0,
      true,
      h3_encode_request_stream(headers, body),
    ),
    keys,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_h3_request_packet(
  conn : @socket.UdpClient,
  destination_connection_id : Bytes,
  packet_number : Int,
  keys : QuicPacketKeys,
  stream_id : Int,
  headers : Array[(String, String)],
  body : Bytes,
) -> QuicProtectedPacket {
  let packet = quic_build_h3_request_packet(
    destination_connection_id, packet_number, keys, stream_id, headers, body,
  )
  conn.send(packet.packet)
  packet
}
