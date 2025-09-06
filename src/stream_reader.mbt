///|
pub struct StreamReader {
  mut closed : Bool
  buffer : @buffer.Buffer
} derive(Show)

///|
pub fn StreamReader::new() -> StreamReader {
  { closed: false, buffer: @buffer.new() }
}

///|
pub fn StreamReader::close(self : StreamReader) -> Unit {
  self.closed = true
}
