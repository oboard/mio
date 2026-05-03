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
