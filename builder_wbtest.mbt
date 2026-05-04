///|
test "builder merges headers" {
  let client = RequestClient::builder()
    .default_header("User-Agent", "mio-test")
    .build()
  let builder = client.get("https://example.com").header("Accept", "text/plain")
  inspect(
    builder.merged_headers(),
    content=(
      #|{"User-Agent": "mio-test", "Accept": "text/plain"}
    ),
  )
}

///|
test "builder stores requested versions" {
  let h2 = RequestClient::builder().http2_prior_knowledge().build()
  let h3 = RequestClient::builder().http3_prior_knowledge().build()
  inspect(h2.version == Http2 && h3.version == Http3, content="true")
}

///|
test "builder can disable certificate verification" {
  let client = RequestClient::builder()
    .danger_accept_invalid_certs(true)
    .build()
  inspect(client.verify, content="false")
}

///|
#cfg(target="native")
test "hpack round trip without huffman" {
  let encoded = hpack_encode_headers([
    (":status", "200"),
    ("content-type", "text/plain"),
    ("x-test", "moonbit"),
  ])
  inspect(
    hpack_decode_headers(encoded),
    content=(
      #|[(":status", "200"), ("content-type", "text/plain"), ("x-test", "moonbit")]
    ),
  )
}

///|
#cfg(target="native")
test "hpack decodes dynamic table references" {
  let block = @buffer.new()
  hpack_write_int(block, 0, prefix_bits=6, first_mask=0x40)
  hpack_write_string(block, "x-test")
  hpack_write_string(block, "moonbit")
  hpack_write_int(block, 62, prefix_bits=7, first_mask=0x80)
  inspect(
    hpack_decode_headers(block.contents()),
    content=(
      #|[("x-test", "moonbit"), ("x-test", "moonbit")]
    ),
  )
}

///|
#cfg(target="native")
test "hpack decodes huffman strings" {
  inspect(
    @utf8.decode_lossy(
      hpack_huffman_decode(b"\xf1\xe3\xc2\xe5\xf2:k\xa0\xab\x90\xf4\xff"),
    ),
    content="www.example.com",
  )
}

///|
#cfg(target="native")
async test "http2 prior knowledge h2c loopback" {
  let server = @socket.TcpServer::new(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      let (conn, _) = server.accept()
      defer conn.close()
      assert_eq(conn.read_exactly(h2_preface.length()), h2_preface)
      let settings = h2_read_frame(conn)
      inspect(settings.frame_type == h2_frame_settings, content="true")
      h2_write_frame(conn, h2_frame_settings, 0, 0, b"")
      let headers = for ;; {
        let frame = h2_read_frame(conn)
        if frame.frame_type == h2_frame_headers {
          break frame
        }
      }
      let decoded = HpackDecoder::new().decode(headers.payload)
      inspect(decoded[0], content="(\":method\", \"GET\")")
      let response_headers = hpack_encode_headers([
        (":status", "200"),
        ("content-length", "2"),
      ])
      h2_write_frame(
        conn, h2_frame_headers, h2_flag_end_headers, 1, response_headers,
      )
      h2_write_frame(conn, h2_frame_data, h2_flag_end_stream, 1, b"ok")
      let _ = try? h2_read_frame(conn)
      let _ = try? h2_read_frame(conn)
      server.close()
    })
    let client = RequestClient::builder().http2_prior_knowledge().build()
    let response = client
      .get("http://127.0.0.1:\{server.addr.port()}/hello")
      .send()
    assert_eq(response.response.code, 200)
    assert_eq(response.text(), "ok")
  })
}

///|
#cfg(target="native")
test "quic varint round trip" {
  let out = @buffer.new()
  quic_write_varint(out, 37)
  quic_write_varint(out, 15293)
  quic_write_varint(out, 494878333)
  let encoded = out.contents()
  let (a, pos) = quic_read_varint(encoded, 0)
  let (b, pos) = quic_read_varint(encoded, pos)
  let (c, _) = quic_read_varint(encoded, pos)
  inspect((a, b, c), content="(37, 15293, 494878333)")
}

///|
#cfg(target="native")
test "http3 headers round trip through qpack" {
  let frame = h3_decode_frame(
    h3_encode_headers([
      (":method", "GET"),
      (":scheme", "https"),
      (":path", "/"),
      (":authority", "example.com"),
      ("x-test", "moonbit"),
    ]),
  )
  inspect(
    h3_decode_headers(frame),
    content=(
      #|[(":method", "GET"), (":scheme", "https"), (":path", "/"), (":authority", "example.com"), ("x-test", "moonbit")]
    ),
  )
}

///|
#cfg(target="native")
test "http3 settings and request stream round trip" {
  let control = h3_encode_control_stream([(0x1, 0), (0x7, 16)])
  let (stream_type, frame_offset) = quic_read_varint(control, 0)
  inspect(stream_type, content="0")
  let settings = h3_decode_settings(
    h3_decode_frame(control, offset=frame_offset),
  )
  inspect(settings, content="[(1, 0), (7, 16)]")
  let stream = h3_encode_request_stream(
    [
      (":method", "POST"),
      (":scheme", "https"),
      (":path", "/submit"),
      (":authority", "example.com"),
    ],
    b"ok",
  )
  let frames = h3_decode_frames(stream)
  inspect(frames.length(), content="2")
  inspect(h3_decode_headers(frames[0])[0], content="(\":method\", \"POST\")")
  inspect(@utf8.decode_lossy(frames[1].payload), content="ok")
}

///|
#cfg(target="native")
test "quic v1 initial secrets match rfc9001" {
  let secrets = quic_initial_secrets(bytes_from_hex("8394c8f03e515708"))
  inspect(
    @crypto.bytes_to_hex_string(secrets.initial_secret),
    content="7db5df06e7a69e432496adedb00851923595221596ae2ae9fb8115c1e9ed0a44",
  )
  inspect(
    @crypto.bytes_to_hex_string(secrets.client_initial_secret),
    content="c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea",
  )
  inspect(
    @crypto.bytes_to_hex_string(quic_initial_key(secrets.client_initial_secret)),
    content="1f369613dd76d5467730efcbe3b1a22d",
  )
  inspect(
    @crypto.bytes_to_hex_string(quic_initial_iv(secrets.client_initial_secret)),
    content="fa044b2f42a3fd3b46fb255c",
  )
  inspect(
    @crypto.bytes_to_hex_string(quic_initial_hp(secrets.client_initial_secret)),
    content="9f50449e04a0e810283a1e9933adedd2",
  )
}

///|
#cfg(target="native")
test "aes128 encrypt block matches nist vector" {
  let key = bytes_from_hex("000102030405060708090a0b0c0d0e0f")
  let block = bytes_from_hex("00112233445566778899aabbccddeeff")
  inspect(
    @crypto.bytes_to_hex_string(aes128_encrypt_block(key, block)),
    content="69c4e0d86a7b0430d8cdb78070b4c55a",
  )
}

///|
#cfg(target="native")
test "aes128 gcm encrypts empty nist vector" {
  let key = bytes_from_hex("00000000000000000000000000000000")
  let iv = bytes_from_hex("000000000000000000000000")
  let result = aes128_gcm_encrypt(key, iv, b"", b"")
  inspect(@crypto.bytes_to_hex_string(result.ciphertext), content="")
  inspect(
    @crypto.bytes_to_hex_string(result.tag),
    content="58e2fccefa7e3061367f1d57a4e7455a",
  )
}

///|
#cfg(target="native")
test "aes128 gcm encrypts one block nist vector" {
  let key = bytes_from_hex("00000000000000000000000000000000")
  let iv = bytes_from_hex("000000000000000000000000")
  let plaintext = bytes_from_hex("00000000000000000000000000000000")
  let result = aes128_gcm_encrypt(key, iv, plaintext, b"")
  inspect(
    @crypto.bytes_to_hex_string(result.ciphertext),
    content="0388dace60b6a392f328c2b971b2fe78",
  )
  inspect(
    @crypto.bytes_to_hex_string(result.tag),
    content="ab6e47d42cec13bdf53a67b21257bddf",
  )
}

///|
#cfg(target="native")
test "quic client initial packet opens after protection" {
  let dcid = bytes_from_hex("8394c8f03e515708")
  let scid = bytes_from_hex("f067a5502a4262b5")
  let payload = bytes_from_hex("060040f1010000ed03030000000000000000")
  let initial_packet = quic_build_client_initial_packet(
    dcid, scid, b"", 2, payload,
  )
  inspect(initial_packet.packet[0] == b'\xc0', content="false")
  let opened = quic_open_client_initial_packet(initial_packet.packet, dcid)
  inspect(opened.packet_number, content="2")
  assert_eq(opened.payload, payload)
}

///|
#cfg(target="native")
test "quic crypto and stream frames round trip" {
  let crypto = quic_encode_crypto_frame(7, b"client-hello")
  let (crypto_frame, crypto_pos) = quic_decode_crypto_frame(crypto, 0)
  inspect(crypto_pos, content="15")
  inspect(crypto_frame.offset, content="7")
  assert_eq(crypto_frame.data, b"client-hello")
  let stream = quic_encode_stream_frame(0, 5, true, b"headers")
  let (stream_frame, stream_pos) = quic_decode_stream_frame(stream, 0)
  inspect(stream_pos, content="11")
  inspect(stream_frame.stream_id, content="0")
  inspect(stream_frame.offset, content="5")
  inspect(stream_frame.fin, content="true")
  assert_eq(stream_frame.data, b"headers")
}

///|
#cfg(target="native")
test "quic ack frame round trips a single range" {
  let encoded = quic_encode_ack(9, 1, 3)
  let (frame, pos) = quic_decode_ack(encoded, 0)
  inspect(pos, content="5")
  inspect(frame.largest_acknowledged, content="9")
  inspect(frame.ack_delay, content="1")
  inspect(frame.first_ack_range, content="3")
}

///|
#cfg(target="native")
test "quic client initial datagram carries crypto frame" {
  let dcid = bytes_from_hex("8394c8f03e515708")
  let scid = bytes_from_hex("f067a5502a4262b5")
  let datagram = quic_build_client_initial_datagram(
    dcid, scid, 0, b"tls-client-hello",
  )
  inspect(datagram.packet.length() >= 1200, content="true")
  let opened = quic_open_client_initial_packet(datagram.packet, dcid)
  let (crypto_frame, pos) = quic_decode_crypto_frame(opened.payload, 0)
  inspect(pos, content="19")
  assert_eq(crypto_frame.data, b"tls-client-hello")
  let mut all_padding = true
  for i in pos..<opened.payload.length() {
    all_padding = all_padding && opened.payload[i] == b'\x00'
  }
  inspect(all_padding, content="true")
}

///|
#cfg(target="native")
async test "quic sends client initial datagram over udp" {
  let dcid = bytes_from_hex("8394c8f03e515708")
  let scid = bytes_from_hex("f067a5502a4262b5")
  let server = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      let buf = FixedArray::make(1500, b'\x00')
      let (n, _) = server.recvfrom(buf)
      inspect(n >= 1200, content="true")
      let packet = quic_copy_slice(buf.unsafe_reinterpret_as_bytes(), 0, n)
      let opened = quic_open_client_initial_packet(packet, dcid)
      let (crypto_frame, _) = quic_decode_crypto_frame(opened.payload, 0)
      assert_eq(crypto_frame.data, b"tls-client-hello")
      server.close()
    })
    let _ = quic_send_client_initial(
      server.addr,
      dcid,
      scid,
      b"tls-client-hello",
    )
  })
}

///|
#cfg(target="native")
test "tls13 client hello encodes h3 quic extensions" {
  let transport_parameters = quic_encode_client_transport_parameters({
    initial_source_connection_id: bytes_from_hex("f067a5502a4262b5"),
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
  let hello = tls13_encode_client_hello({
    server_name: "example.com",
    alpn: "h3",
    random: Bytes::make(32, b'\x11'),
    legacy_session_id: Bytes::make(8, b'\x22'),
    x25519_public_key: Bytes::make(32, b'\x33'),
    transport_parameters,
  })
  inspect(hello[0].to_int(), content="1")
  assert_true(hello.length() > 140)
  inspect(@crypto.bytes_to_hex_string(hello[9:13]), content="11111111")
  let params = quic_decode_transport_parameters(transport_parameters)
  inspect(params.length(), content="10")
  inspect(params[0].identifier, content="15")
  inspect(
    @crypto.bytes_to_hex_string(params[0].value),
    content="f067a5502a4262b5",
  )
}

///|
#cfg(target="native")
test "x25519 derives rfc7748 public keys and shared secret" {
  let alice_private = bytes_from_hex(
    "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a",
  )
  let bob_private = bytes_from_hex(
    "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb",
  )
  let alice_public = x25519_base(alice_private)
  let bob_public = x25519_base(bob_private)
  inspect(
    @crypto.bytes_to_hex_string(alice_public),
    content="8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a",
  )
  inspect(
    @crypto.bytes_to_hex_string(bob_public),
    content="de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f",
  )
  let alice_shared = x25519(alice_private, bob_public)
  let bob_shared = x25519(bob_private, alice_public)
  inspect(
    @crypto.bytes_to_hex_string(alice_shared),
    content="4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742",
  )
  assert_eq(alice_shared, bob_shared)
}

///|
#cfg(target="native")
test "tls13 key schedule derives handshake traffic keys" {
  let shared = bytes_from_hex(
    "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742",
  )
  let transcript = tls13_transcript_hash([b"clienthello", b"||", b"serverhello"])
  inspect(
    @crypto.bytes_to_hex_string(transcript),
    content="d98be9c5876e397a6beabd1ccbc26d3c739a1fd36bb72a618eb1dab5f588eacb",
  )
  let secrets = tls13_derive_handshake_secrets(shared, transcript)
  inspect(
    @crypto.bytes_to_hex_string(secrets.early_secret),
    content="b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
  )
  inspect(
    @crypto.bytes_to_hex_string(secrets.handshake_secret),
    content="6ba15db66ab3c7ca018f1d419801858133627705680281f983044762f85cb5c3",
  )
  inspect(
    @crypto.bytes_to_hex_string(secrets.client_handshake_traffic_secret),
    content="f919601dad1105788e27075132951d50a026c726583f82d27bdd990fe2ca01ed",
  )
  inspect(
    @crypto.bytes_to_hex_string(secrets.server_handshake_traffic_secret),
    content="84f047c1eab5ad44123a2ed7f4a5a6a449d4e5d05b9bda7490a15ccea2d47885",
  )
  let client_keys = tls13_derive_traffic_keys(
    secrets.client_handshake_traffic_secret,
  )
  inspect(
    @crypto.bytes_to_hex_string(client_keys.key),
    content="fff07e4f8ee99931eddb1dd042e52248",
  )
  inspect(
    @crypto.bytes_to_hex_string(client_keys.iv),
    content="9870869cbb0cbdeacd8bd931",
  )
  inspect(
    @crypto.bytes_to_hex_string(
      tls13_finished_verify_data(client_keys.finished_key, transcript),
    ),
    content="bc89f311fcefa56402b2e7a196d4e09e2028c7ab33bd20d4692273fdadef9b0f",
  )
}

///|
#cfg(target="native")
test "tls13 parses server hello encrypted extensions and finished" {
  let server_key = Bytes::make(32, b'\x44')
  let key_share_payload = @buffer.new()
  tls13_write_u16(key_share_payload, tls13_group_x25519)
  tls13_write_u16(key_share_payload, server_key.length())
  key_share_payload.write_bytes(server_key)
  let extensions = @buffer.new()
  extensions.write_bytes(
    tls13_extension(tls13_ext_supported_versions, b"\x03\x04"),
  )
  extensions.write_bytes(
    tls13_extension(tls13_ext_key_share, key_share_payload.contents()),
  )
  let server_body = @buffer.new()
  tls13_write_u16(server_body, 0x0303)
  server_body.write_bytes(Bytes::make(32, b'\x55'))
  server_body.write_byte(b'\x08')
  server_body.write_bytes(Bytes::make(8, b'\x22'))
  tls13_write_u16(server_body, 0x1301)
  server_body.write_byte(b'\x00')
  tls13_write_u16(server_body, extensions.length())
  server_body.write_bytes(extensions.contents())
  let server_message = @buffer.new()
  server_message.write_byte(b'\x02')
  tls13_write_u24(server_message, server_body.length())
  server_message.write_bytes(server_body.contents())
  let server_hello = tls13_parse_server_hello(server_message.contents())
  inspect(server_hello.cipher_suite, content="4865")
  assert_eq(server_hello.x25519_public_key, server_key)

  let transport_parameters = quic_encode_client_transport_parameters({
    initial_source_connection_id: bytes_from_hex("f067a5502a4262b5"),
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
  let ee_extensions = @buffer.new()
  ee_extensions.write_bytes(tls13_extension(tls13_ext_alpn, b"\x00\x03\x02h3"))
  ee_extensions.write_bytes(
    tls13_extension(tls13_ext_quic_transport_parameters, transport_parameters),
  )
  let ee_body = @buffer.new()
  tls13_write_u16(ee_body, ee_extensions.length())
  ee_body.write_bytes(ee_extensions.contents())
  let ee_message = @buffer.new()
  ee_message.write_byte(b'\x08')
  tls13_write_u24(ee_message, ee_body.length())
  ee_message.write_bytes(ee_body.contents())
  let encrypted_extensions = tls13_parse_encrypted_extensions(
    ee_message.contents(),
  )
  inspect(encrypted_extensions.alpn, content="h3")
  assert_eq(encrypted_extensions.transport_parameters, transport_parameters)

  let finished_message = @buffer.new()
  finished_message.write_byte(b'\x14')
  tls13_write_u24(finished_message, 32)
  finished_message.write_bytes(Bytes::make(32, b'\x66'))
  let finished = tls13_parse_finished(finished_message.contents())
  assert_eq(finished.verify_data, Bytes::make(32, b'\x66'))
}

///|
#cfg(target="native")
test "tls13 processes server handshake and verifies finished" {
  let client_private = bytes_from_hex(
    "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a",
  )
  let server_private = bytes_from_hex(
    "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb",
  )
  let client_public = x25519_base(client_private)
  let server_public = x25519_base(server_private)
  let transport_parameters = quic_encode_client_transport_parameters({
    initial_source_connection_id: bytes_from_hex("f067a5502a4262b5"),
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
    server_name: "example.com",
    alpn: "h3",
    random: Bytes::make(32, b'\x11'),
    legacy_session_id: Bytes::make(8, b'\x22'),
    x25519_public_key: client_public,
    transport_parameters,
  })
  let key_share_payload = @buffer.new()
  tls13_write_u16(key_share_payload, tls13_group_x25519)
  tls13_write_u16(key_share_payload, server_public.length())
  key_share_payload.write_bytes(server_public)
  let sh_extensions = @buffer.new()
  sh_extensions.write_bytes(
    tls13_extension(tls13_ext_supported_versions, b"\x03\x04"),
  )
  sh_extensions.write_bytes(
    tls13_extension(tls13_ext_key_share, key_share_payload.contents()),
  )
  let sh_body = @buffer.new()
  tls13_write_u16(sh_body, 0x0303)
  sh_body.write_bytes(Bytes::make(32, b'\x55'))
  sh_body.write_byte(b'\x08')
  sh_body.write_bytes(Bytes::make(8, b'\x22'))
  tls13_write_u16(sh_body, 0x1301)
  sh_body.write_byte(b'\x00')
  tls13_write_u16(sh_body, sh_extensions.length())
  sh_body.write_bytes(sh_extensions.contents())
  let server_hello = @buffer.new()
  server_hello.write_byte(b'\x02')
  tls13_write_u24(server_hello, sh_body.length())
  server_hello.write_bytes(sh_body.contents())
  let server_hello = server_hello.contents()

  let ee_extensions = @buffer.new()
  ee_extensions.write_bytes(tls13_extension(tls13_ext_alpn, b"\x00\x03\x02h3"))
  ee_extensions.write_bytes(
    tls13_extension(tls13_ext_quic_transport_parameters, transport_parameters),
  )
  let ee_body = @buffer.new()
  tls13_write_u16(ee_body, ee_extensions.length())
  ee_body.write_bytes(ee_extensions.contents())
  let encrypted_extensions = @buffer.new()
  encrypted_extensions.write_byte(b'\x08')
  tls13_write_u24(encrypted_extensions, ee_body.length())
  encrypted_extensions.write_bytes(ee_body.contents())
  let encrypted_extensions = encrypted_extensions.contents()

  let shared = x25519(server_private, client_public)
  let secrets = tls13_derive_handshake_secrets(
    shared,
    tls13_transcript_hash([client_hello, server_hello]),
  )
  let server_keys = tls13_derive_traffic_keys(
    secrets.server_handshake_traffic_secret,
  )
  let verify_data = tls13_finished_verify_data(
    server_keys.finished_key,
    tls13_transcript_hash([client_hello, server_hello, encrypted_extensions]),
  )
  let finished = @buffer.new()
  finished.write_byte(b'\x14')
  tls13_write_u24(finished, verify_data.length())
  finished.write_bytes(verify_data)
  let result = tls13_process_server_handshake(
    client_private,
    client_hello,
    server_hello,
    encrypted_extensions,
    finished.contents(),
  )
  inspect(result.encrypted_extensions.alpn, content="h3")
  assert_eq(result.server_handshake_keys.key, server_keys.key)
  let bad_finished = @buffer.new()
  bad_finished.write_byte(b'\x14')
  tls13_write_u24(bad_finished, 32)
  bad_finished.write_bytes(Bytes::make(32, b'\x00'))
  assert_true(
    (try? tls13_process_server_handshake(
      client_private,
      client_hello,
      server_hello,
      encrypted_extensions,
      bad_finished.contents(),
    ))
    is Err(_),
  )
}
