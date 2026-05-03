
///|
pub(all) struct Buffer {
  mut buf : FixedArray[Byte]
  mut start : Int
  mut len : Int
}

///|
#as_free_fn
pub fn Buffer::new(size : Int) -> Buffer {
  { buf: FixedArray::make(size, 0), start: 0, len: 0 }
}

///|
pub fn Buffer::clear(buf : Buffer) -> Unit {
  buf.buf = []
  buf.start = 0
  buf.len = 0
}

///|
const SEGMENT_SIZE = 1024

///|
pub fn Buffer::enlarge_to(self : Buffer, n : Int) -> Unit {
  let capacity = self.buf.length()
  if self.start + n <= capacity {
    return
  }
  if n <= capacity {
    self.buf.blit_to(self.buf, src_offset=self.start, len=self.len)
    self.start = 0
    return
  }
  let padding = n % SEGMENT_SIZE
  let target_len = if padding == 0 { n } else { n - padding + SEGMENT_SIZE }
  let new_buf = FixedArray::make(target_len, b'0')
  self.buf.blit_to(new_buf, src_offset=self.start, dst_offset=0, len=self.len)
  self.buf = new_buf
  self.start = 0
}

///|
pub fn Buffer::drop(self : Buffer, n : Int) -> Unit {
  guard n <= self.len
  self.len -= n
  if self.len == 0 {
    self.start = 0
  } else {
    self.start += n
  }
}
