///|
let crc32_table : FixedArray[UInt] = FixedArray::makei(256, i => {
  let mut crc = i.reinterpret_as_uint()
  for _ in 0..<8 {
    crc = if (crc & 1U) == 0U { crc >> 1 } else { (crc >> 1) ^ 0xedb88320U }
  }
  crc
})

///|
fn crc32_update(current : UInt, chunk : BytesView) -> UInt {
  for byte in chunk; crc = current {
    let index = ((crc ^ byte.to_uint()) & 0xffU).reinterpret_as_int()
    continue crc32_table[index] ^ (crc >> 8)
  } nobreak {
    crc
  }
}
