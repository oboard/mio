
///|
test "parse cookie success" {
  debug_inspect(
    Cookie::parse("Cookie=value"),
    content=(
      #|{
      #|  name: "Cookie",
      #|  value: "value",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: [],
      #|}
    ),
  )
  debug_inspect(
    try? Cookie::parse("Cookie="),
    content=(
      #|Ok(
      #|  {
      #|    name: "Cookie",
      #|    value: "",
      #|    path: None,
      #|    expires_raw: None,
      #|    max_age: None,
      #|    domain: None,
      #|    secure: false,
      #|    http_only: false,
      #|    extensions: [],
      #|  },
      #|)
    ),
  )
  debug_inspect(
    Cookie::parse(
      "Cookie2=value2;path=/path/to/xxx; EXPIRES=Sun, 06 Nov 1994 08:49:37 GMT;Max-age=420000; domain=example.moonbitlang.com;SECURE; httponly; whatever=whatever",
    ),
    content=(
      #|{
      #|  name: "Cookie2",
      #|  value: "value2",
      #|  path: Some("/path/to/xxx"),
      #|  expires_raw: Some("Sun, 06 Nov 1994 08:49:37 GMT"),
      #|  max_age: Some(420000),
      #|  domain: Some("example.moonbitlang.com"),
      #|  secure: true,
      #|  http_only: true,
      #|  extensions: ["whatever=whatever"],
      #|}
    ),
  )
}

///|
test "parse cookie failure" {
  debug_inspect(
    try? Cookie::parse("Cookie"),
    content=(
      #|Err(BadRequest)
    ),
  )
  debug_inspect(
    try? Cookie::parse("Cookie=value;Max-Age=xxx"),
    content=(
      #|Err(BadRequest)
    ),
  )
}
