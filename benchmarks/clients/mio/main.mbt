///|
let usage : String =
  #|Usage: moon run benchmarks/clients/mio -- [OPTIONS]
  #|
  #|Options:
  #|  --url URL          benchmark URL
  #|  --requests N      measured request count
  #|  --warmup N        unmeasured warmup request count
  #|  --payload-bytes N  expected response body length
  #|  -h, --help        show this message

///|
fn split_origin_path(url : String) -> (String, String) raise {
  guard url.find("://") is Some(protocol_len) else { fail("invalid URL") }
  let rest = url[protocol_len + 3:]
  if rest.find("/") is Some(path_start) {
    let origin_len = protocol_len + 3 + path_start
    (url[:origin_len].to_owned(), rest[path_start:].to_owned())
  } else {
    (url, "/")
  }
}

///|
fn parse_positive_int(name : String, value : String) -> Int raise {
  let parsed = @string.parse_int(value) catch { _ => fail("invalid \{name}") }
  guard parsed > 0 else { fail("invalid \{name}") }
  parsed
}

///|
async fn issue_request(
  client : @mio_client.Client,
  path : String,
  payload_bytes : Int,
) -> Int {
  let response = client.get(path)
  guard response.code == 200 else { fail("unexpected status \{response.code}") }
  let body = client.read_exactly(payload_bytes)
  body.length()
}

///|
async fn main {
  let mut url = "http://127.0.0.1:3200/payload"
  let mut requests = 10000
  let mut warmup = 200
  let mut payload_bytes = 128

  for args = @env.args()[1:] {
    match args {
      [] => break
      ["--url", .. rest] => {
        guard rest is [value, .. rest] else { fail("expected URL") }
        url = value
        continue rest
      }
      ["--requests", .. rest] => {
        guard rest is [value, .. rest] else { fail("expected request count") }
        requests = parse_positive_int("--requests", value)
        continue rest
      }
      ["--warmup", .. rest] => {
        guard rest is [value, .. rest] else { fail("expected warmup count") }
        warmup = parse_positive_int("--warmup", value)
        continue rest
      }
      ["--payload-bytes", .. rest] => {
        guard rest is [value, .. rest] else {
          fail("expected response body length")
        }
        payload_bytes = parse_positive_int("--payload-bytes", value)
        continue rest
      }
      ["-h" | "--help", ..] => {
        println(usage)
        return
      }
      [opt, ..] => fail("unknown option `\{opt}`")
    }
  }

  let (origin, path) = split_origin_path(url)
  let client = @mio_client.Client::new(origin, headers={
    "Accept-Encoding": "identity",
  })
  defer client.close()

  for _ in 0..<warmup {
    ignore(issue_request(client, path, payload_bytes))
  }

  let started = @bench.monotonic_clock_start()
  let mut bytes : Int64 = 0
  for _ in 0..<requests {
    bytes += issue_request(client, path, payload_bytes).to_int64()
  }
  let elapsed_ms = @bench.monotonic_clock_end(started) / 1000.0
  let requests_per_sec = requests.to_double() * 1000.0 / elapsed_ms

  let output =
    $|{"runtime":"mio","requests":\{requests},"warmup":\{warmup},"elapsed_ms":\{elapsed_ms},"requests_per_sec":\{requests_per_sec},"bytes":\{bytes}}
  println(output)
}
