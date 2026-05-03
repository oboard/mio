///|
test "decoder rejects invalid gzip header" {
  let result = try? decode(
    b"\x1f\x8b\x08\x02\x00\x00\x00\x00\x00\x00\x1d\x26\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    expected_len=0,
  )
  assert_true(result is Err(_))
}

///|
test "decoder verifies trailer automatically" {
  let encoded = encode(b"\x00")
  let corrupted = encoded[:encoded.length() - 8].to_owned() +
    b"\x00\x00\x00\x00\x01\x00\x00\x00"
  let result = try? decode(corrupted, expected_len=1)
  assert_true(result is Err(_))
}
