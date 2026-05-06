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
async fn quic_send_tls13_client_initial_on_conn(
  conn : @socket.UdpClient,
  server_name : String,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  client_private_key : Bytes,
  random : Bytes,
  legacy_session_id : Bytes,
  token? : Bytes = b"",
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
  let datagram = quic_build_client_initial_datagram(
    destination_connection_id,
    source_connection_id,
    0,
    client_hello,
    token~,
  )
  conn.send(datagram.packet)
  { datagram, client_hello, client_public_key, transport_parameters }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_tls13_client_finished_packet(
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  packet_number : Int,
  keys : QuicPacketKeys,
  finished_message : Bytes,
  ack_largest? : Int = -1,
) -> QuicProtectedPacket raise {
  let payload = @buffer.new()
  if ack_largest >= 0 {
    payload.write_bytes(quic_encode_ack(ack_largest, 0, 0))
  }
  payload.write_bytes(quic_encode_crypto_frame(0, finished_message))
  quic_build_handshake_packet(
    destination_connection_id,
    source_connection_id,
    packet_number,
    payload.contents(),
    keys,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_tls13_client_finished(
  conn : @socket.UdpClient,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  packet_number : Int,
  keys : QuicPacketKeys,
  finished_message : Bytes,
  ack_largest? : Int = -1,
) -> QuicProtectedPacket {
  let packet = quic_build_tls13_client_finished_packet(
    destination_connection_id,
    source_connection_id,
    packet_number,
    keys,
    finished_message,
    ack_largest~,
  )
  conn.send(packet.packet)
  packet
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_h3_client_request_packet(
  destination_connection_id : Bytes,
  packet_number : Int,
  keys : QuicPacketKeys,
  stream_id : Int,
  headers : Array[(String, String)],
  body : Bytes,
  ack_largest? : Int = -1,
) -> QuicProtectedPacket raise {
  let payload = @buffer.new()
  if ack_largest >= 0 {
    payload.write_bytes(quic_encode_ack(ack_largest, 0, 0))
  }
  payload.write_bytes(
    quic_encode_stream_frame(2, 0, false, h3_encode_control_stream([])),
  )
  payload.write_bytes(
    quic_encode_stream_frame(
      stream_id,
      0,
      true,
      h3_encode_request_stream(headers, body),
    ),
  )
  quic_build_short_packet(
    destination_connection_id,
    packet_number,
    payload.contents(),
    keys,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_recv_datagram_packets(conn : @socket.UdpClient) -> Array[Bytes] {
  let buf = FixedArray::make(4096, b'\x00')
  let n = conn.recv(buf)
  quic_split_datagram(quic_copy_slice(buf.unsafe_reinterpret_as_bytes(), 0, n))
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_recv_tls13_server_handshake(
  conn : @socket.UdpClient,
  client_private_key : Bytes,
  client_hello : Bytes,
  original_destination_connection_id : Bytes,
  max_datagrams? : Int = 8,
  verify_certificate? : Bool = true,
  retry_source_connection_id? : Bytes = b"",
) -> QuicTlsServerHandshakeResult {
  let mut initial_destination_connection_id = original_destination_connection_id
  let mut server_initial_packet : Bytes? = None
  let server_handshake_packets = []
  let mut retried = false
  for _ in 0..<max_datagrams {
    for packet in quic_recv_datagram_packets(conn) {
      let long_header = quic_parse_long_header(packet) catch { _ => continue }
      if long_header.packet_type == 3 &&
        !retried &&
        retry_source_connection_id.length() > 0 {
        let retry = quic_parse_retry_packet(
          packet,
          original_destination_connection_id~,
        )
        let retry_initial = quic_build_client_initial_datagram(
          retry.source_connection_id,
          retry_source_connection_id,
          0,
          client_hello,
          token=retry.token,
        )
        conn.send(retry_initial.packet)
        initial_destination_connection_id = retry.source_connection_id
        retried = true
        server_initial_packet = None
        server_handshake_packets.clear()
      } else if long_header.packet_type == 0 && server_initial_packet is None {
        server_initial_packet = Some(packet)
      } else if long_header.packet_type == 2 {
        server_handshake_packets.push(packet)
      }
    }
    if server_initial_packet is Some(initial) &&
      server_handshake_packets.length() > 0 {
      try
        quic_process_tls13_server_handshake(
          client_private_key,
          client_hello,
          initial_destination_connection_id,
          initial,
          server_handshake_packets,
          verify_certificate~,
        )
      catch {
        _ => ()
      } noraise {
        result => return result
      }
    }
  }
  raise Http3HandshakeFailed
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_recv_h3_response_loop(
  conn : @socket.UdpClient,
  destination_connection_id_length : Int,
  keys : QuicPacketKeys,
  stream_id? : Int = 0,
  max_datagrams? : Int = 16,
) -> H3DecodedResponse {
  let packets = []
  for _ in 0..<max_datagrams {
    for packet in quic_recv_datagram_packets(conn) {
      if packet.length() > 0 && (packet[0].to_int() & 0x80) == 0 {
        packets.push(packet)
      }
    }
    try
      quic_decode_h3_response_packets(
        packets,
        destination_connection_id_length,
        keys,
        stream_id~,
      )
    catch {
      _ => ()
    } noraise {
      response => return response
    }
  }
  raise Http3ResponseIncomplete
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

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_recv_h3_response_packet(
  conn : @socket.UdpClient,
  destination_connection_id_length : Int,
  keys : QuicPacketKeys,
  stream_id? : Int = 0,
) -> H3DecodedResponse {
  let buf = FixedArray::make(4096, b'\x00')
  let n = conn.recv(buf)
  let packet = quic_copy_slice(buf.unsafe_reinterpret_as_bytes(), 0, n)
  quic_decode_h3_response_packets(
    [packet],
    destination_connection_id_length,
    keys,
    stream_id~,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_h3_request_and_recv_response(
  conn : @socket.UdpClient,
  request_destination_connection_id : Bytes,
  response_destination_connection_id_length : Int,
  packet_number : Int,
  request_keys : QuicPacketKeys,
  response_keys : QuicPacketKeys,
  stream_id : Int,
  headers : Array[(String, String)],
  body : Bytes,
) -> H3DecodedResponse {
  let _ = quic_send_h3_request_packet(
    conn, request_destination_connection_id, packet_number, request_keys, stream_id,
    headers, body,
  )
  quic_recv_h3_response_packet(
    conn,
    response_destination_connection_id_length,
    response_keys,
    stream_id~,
  )
}
