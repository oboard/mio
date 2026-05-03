///|
#cfg(target="native")
priv suberror QpackError {
  QpackBadPrefix
  QpackBadString
  QpackBadStaticIndex(Int)
  QpackDynamicUnsupported
} derive(Debug, ToJson)

///|
#cfg(target="native")
fn qpack_static_entry(index : Int) -> (String, String) raise {
  match index {
    0 => (":authority", "")
    1 => (":path", "/")
    4 => ("content-length", "0")
    14 => ("set-cookie", "")
    15 => (":method", "CONNECT")
    16 => (":method", "DELETE")
    17 => (":method", "GET")
    18 => (":method", "HEAD")
    19 => (":method", "OPTIONS")
    20 => (":method", "POST")
    21 => (":method", "PUT")
    22 => (":scheme", "http")
    23 => (":scheme", "https")
    25 => (":status", "200")
    31 => ("accept-encoding", "gzip, deflate, br")
    42 => ("content-encoding", "br")
    43 => ("content-encoding", "gzip")
    46 => ("content-type", "application/json")
    53 => ("content-type", "text/plain")
    63 => (":status", "100")
    64 => (":status", "204")
    65 => (":status", "206")
    66 => (":status", "302")
    67 => (":status", "400")
    68 => (":status", "403")
    69 => (":status", "421")
    70 => (":status", "425")
    71 => (":status", "500")
    84 => ("authorization", "")
    92 => ("server", "")
    95 => ("user-agent", "")
    _ => raise QpackBadStaticIndex(index)
  }
}

///|
#cfg(target="native")
fn qpack_static_name_index(name : String) -> Int? {
  match name {
    ":authority" => Some(0)
    ":path" => Some(1)
    "content-length" => Some(4)
    "set-cookie" => Some(14)
    ":method" => Some(17)
    ":scheme" => Some(22)
    ":status" => Some(25)
    "accept-encoding" => Some(31)
    "content-encoding" => Some(43)
    "content-type" => Some(53)
    "authorization" => Some(84)
    "server" => Some(92)
    "user-agent" => Some(95)
    _ => None
  }
}

///|
#cfg(target="native")
fn qpack_write_string(
  out : @buffer.Buffer,
  value : String,
  prefix_bits~ : Int,
  first_mask~ : Int,
) -> Unit {
  let bytes = @utf8.encode(value)
  hpack_write_int(out, bytes.length(), prefix_bits~, first_mask~)
  out.write_bytes(bytes)
}

///|
#cfg(target="native")
fn qpack_read_string(
  data : Bytes,
  offset : Int,
  prefix_bits~ : Int,
) -> (String, Int) raise {
  guard offset < data.length() else { raise QpackBadString }
  let huffman = (data[offset].to_int() & (1 << prefix_bits)) != 0
  let (len, pos) = hpack_read_int(data, offset, prefix_bits~)
  guard pos + len <= data.length() else { raise QpackBadString }
  let raw = @buffer.new()
  raw.write_bytes(data[pos:pos + len])
  let decoded = if huffman {
    hpack_huffman_decode(raw.contents())
  } else {
    raw.contents()
  }
  (@utf8.decode_lossy(decoded), pos + len)
}

///|
#cfg(target="native")
fn qpack_encode_header_block(headers : Array[(String, String)]) -> Bytes {
  let out = @buffer.new()
  out.write_byte(b'\x00')
  out.write_byte(b'\x00')
  for item in headers {
    let (name, value) = item
    let name = name.to_lower()
    match qpack_static_name_index(name) {
      Some(index) => {
        hpack_write_int(out, index, prefix_bits=4, first_mask=0x50)
        qpack_write_string(out, value, prefix_bits=7, first_mask=0)
      }
      None => {
        qpack_write_string(out, name, prefix_bits=3, first_mask=0x20)
        qpack_write_string(out, value, prefix_bits=7, first_mask=0)
      }
    }
  }
  out.contents()
}

///|
#cfg(target="native")
fn qpack_decode_header_block(block : Bytes) -> Array[(String, String)] raise {
  let (required_insert_count, pos) = hpack_read_int(block, 0, prefix_bits=8)
  guard required_insert_count == 0 else { raise QpackDynamicUnsupported }
  let (delta_base, pos) = hpack_read_int(block, pos, prefix_bits=7)
  guard delta_base == 0 else { raise QpackDynamicUnsupported }
  let headers = []
  for pos = pos; pos < block.length(); {
    let first = block[pos].to_int()
    if (first & 0x80) != 0 {
      guard (first & 0x40) != 0 else { raise QpackDynamicUnsupported }
      let (index, pos) = hpack_read_int(block, pos, prefix_bits=6)
      headers.push(qpack_static_entry(index))
      continue pos
    } else if (first & 0xc0) == 0x40 {
      guard (first & 0x10) != 0 else { raise QpackDynamicUnsupported }
      let (index, pos) = hpack_read_int(block, pos, prefix_bits=4)
      let (name, _) = qpack_static_entry(index)
      let (value, pos) = qpack_read_string(block, pos, prefix_bits=7)
      headers.push((name, value))
      continue pos
    } else if (first & 0xe0) == 0x20 {
      let (name, pos) = qpack_read_string(block, pos, prefix_bits=3)
      let (value, pos) = qpack_read_string(block, pos, prefix_bits=7)
      headers.push((name, value))
      continue pos
    } else {
      raise QpackBadPrefix
    }
  }
  headers
}
