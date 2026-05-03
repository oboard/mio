///|
fn encode_int(value : Int, base~ : Int) -> Bytes {
  let len = for x = value, len = 1; x >= base; {
    continue x / base, len + 1
  } nobreak {
    len
  }
  let out = FixedArray::make(len, b'0')
  for x = value, i = len - 1; i >= 0; x = x / base, i = i - 1 {
    let digit = x % base
    let chr = if digit < 10 { digit + '0' } else { digit - 10 + 'a' }
    out[i] = chr.to_byte()
  }
  out.unsafe_reinterpret_as_bytes()
}
