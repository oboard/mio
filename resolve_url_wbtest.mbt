
///|
test "resolve_url" {
  debug_inspect(
    try? resolve_url("http://www.example.org"),
    content=(
      #|Ok((Http, 80, "www.example.org", "/"))
    ),
  )
  debug_inspect(
    try? resolve_url("http://www.example.org/path/to"),
    content=(
      #|Ok((Http, 80, "www.example.org", "/path/to"))
    ),
  )
  debug_inspect(
    try? resolve_url("https://www.example.org/path/to?search=q"),
    content=(
      #|Ok((Https, 443, "www.example.org", "/path/to?search=q"))
    ),
  )
  debug_inspect(
    try? resolve_url("ftp://www.example.org"),
    content=(
      #|Err(UnsupportedProtocol("ftp"))
    ),
  )
  debug_inspect(
    try? resolve_url("http://www.example.org:10042"),
    content=(
      #|Ok((Http, 10042, "www.example.org", "/"))
    ),
  )
  debug_inspect(
    try? resolve_url("http://www.example.org:10042/path"),
    content=(
      #|Ok((Http, 10042, "www.example.org", "/path"))
    ),
  )
  debug_inspect(
    try? resolve_url("http://www.example.org:0"),
    content="Err(InvalidFormat)",
  )
  debug_inspect(
    try? resolve_url("http://www.example.org:100042"),
    content="Err(InvalidFormat)",
  )
}
