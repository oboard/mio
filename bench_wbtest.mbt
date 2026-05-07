///|
#cfg(target="native")
let bench_headers : Array[(String, String)] = [
  (":status", "200"),
  ("content-type", "application/json"),
  ("content-length", "128"),
  ("cache-control", "no-cache"),
  ("x-powered-by", "mio"),
]

///|
#cfg(target="native")
test "bench resolve_url" (b : @bench.T) {
  b.bench(name="resolve_url_local_http", () => {
    b.keep(try! resolve_url("http://127.0.0.1:3000/payload?size=128"))
  })
  b.bench(name="resolve_url_tls_with_port", () => {
    b.keep(try! resolve_url("https://example.com:8443/api/v1/items"))
  })
}

///|
#cfg(target="native")
test "bench cookie_parse" (b : @bench.T) {
  b.bench(name="cookie_parse_set_cookie", () => {
    b.keep(
      try! Cookie::parse(
        "session=moonbit; Path=/; Max-Age=3600; HttpOnly; Secure"[:],
      ),
    )
  })
}

///|
#cfg(target="native")
test "bench hpack" (b : @bench.T) {
  let encoded = hpack_encode_headers(bench_headers)
  b.bench(name="hpack_encode_headers", () => {
    b.keep(hpack_encode_headers(bench_headers))
  })
  b.bench(name="hpack_decode_headers", () => {
    b.keep(try! hpack_decode_headers(encoded))
  })
}
