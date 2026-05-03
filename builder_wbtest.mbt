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
