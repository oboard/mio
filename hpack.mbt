///|
#cfg(target="native")
pub suberror HpackError {
  HpackBadInteger
  HpackBadString
  HpackBadHuffmanPadding
  HpackHuffmanEOS
  HpackBadIndex(Int)
  HpackBadDynamicTableSize(Int)
} derive(Debug, ToJson)

///|
#cfg(target="native")
let hpack_static_table_len : Int = 61

///|
#cfg(target="native")
priv struct HpackDecoder {
  dynamic_table : Array[(String, String)]
  mut dynamic_size : Int
  mut max_dynamic_size : Int
}

///|
#cfg(target="native")
fn HpackDecoder::new(max_dynamic_size? : Int = 4096) -> HpackDecoder {
  { dynamic_table: [], dynamic_size: 0, max_dynamic_size }
}

///|
#cfg(target="native")
fn hpack_entry_size(name : String, value : String) -> Int {
  name.length() + value.length() + 32
}

///|
#cfg(target="native")
fn HpackDecoder::evict(self : HpackDecoder) -> Unit {
  while self.dynamic_size > self.max_dynamic_size &&
        !self.dynamic_table.is_empty() {
    let last = self.dynamic_table[self.dynamic_table.length() - 1]
    let (name, value) = last
    self.dynamic_size -= hpack_entry_size(name, value)
    self.dynamic_table.unsafe_pop_back()
  }
}

///|
#cfg(target="native")
fn HpackDecoder::set_max_dynamic_size(
  self : HpackDecoder,
  max_size : Int,
) -> Unit raise {
  guard max_size >= 0 else { raise HpackBadDynamicTableSize(max_size) }
  self.max_dynamic_size = max_size
  self.evict()
}

///|
#cfg(target="native")
fn HpackDecoder::insert(
  self : HpackDecoder,
  name : String,
  value : String,
) -> Unit {
  let size = hpack_entry_size(name, value)
  if size > self.max_dynamic_size {
    self.dynamic_table.clear()
    self.dynamic_size = 0
    return
  }
  self.dynamic_table.push((name, value))
  for i = self.dynamic_table.length() - 1; i > 0; i = i - 1 {
    self.dynamic_table[i] = self.dynamic_table[i - 1]
  }
  self.dynamic_table[0] = (name, value)
  self.dynamic_size += size
  self.evict()
}

///|
#cfg(target="native")
fn HpackDecoder::get(
  self : HpackDecoder,
  index : Int,
) -> (String, String) raise {
  guard index > 0 else { raise HpackBadIndex(index) }
  if index <= hpack_static_table_len {
    hpack_static_entry(index)
  } else {
    let dynamic_index = index - hpack_static_table_len - 1
    guard dynamic_index >= 0 && dynamic_index < self.dynamic_table.length() else {
      raise HpackBadIndex(index)
    }
    self.dynamic_table[dynamic_index]
  }
}

///|
#cfg(target="native")
fn hpack_static_entry(index : Int) -> (String, String) raise {
  match index {
    1 => (":authority", "")
    2 => (":method", "GET")
    3 => (":method", "POST")
    4 => (":path", "/")
    5 => (":path", "/index.html")
    6 => (":scheme", "http")
    7 => (":scheme", "https")
    8 => (":status", "200")
    9 => (":status", "204")
    10 => (":status", "206")
    11 => (":status", "304")
    12 => (":status", "400")
    13 => (":status", "404")
    14 => (":status", "500")
    15 => ("accept-charset", "")
    16 => ("accept-encoding", "gzip, deflate")
    17 => ("accept-language", "")
    18 => ("accept-ranges", "")
    19 => ("accept", "")
    20 => ("access-control-allow-origin", "")
    21 => ("age", "")
    22 => ("allow", "")
    23 => ("authorization", "")
    24 => ("cache-control", "")
    25 => ("content-disposition", "")
    26 => ("content-encoding", "")
    27 => ("content-language", "")
    28 => ("content-length", "")
    29 => ("content-location", "")
    30 => ("content-range", "")
    31 => ("content-type", "")
    32 => ("cookie", "")
    33 => ("date", "")
    34 => ("etag", "")
    35 => ("expect", "")
    36 => ("expires", "")
    37 => ("from", "")
    38 => ("host", "")
    39 => ("if-match", "")
    40 => ("if-modified-since", "")
    41 => ("if-none-match", "")
    42 => ("if-range", "")
    43 => ("if-unmodified-since", "")
    44 => ("last-modified", "")
    45 => ("link", "")
    46 => ("location", "")
    47 => ("max-forwards", "")
    48 => ("proxy-authenticate", "")
    49 => ("proxy-authorization", "")
    50 => ("range", "")
    51 => ("referer", "")
    52 => ("refresh", "")
    53 => ("retry-after", "")
    54 => ("server", "")
    55 => ("set-cookie", "")
    56 => ("strict-transport-security", "")
    57 => ("transfer-encoding", "")
    58 => ("user-agent", "")
    59 => ("vary", "")
    60 => ("via", "")
    61 => ("www-authenticate", "")
    _ => raise HpackBadIndex(index)
  }
}

///|
#cfg(target="native")
fn hpack_static_name_index(name : String) -> Int {
  match name {
    ":authority" => 1
    ":method" => 2
    ":path" => 4
    ":scheme" => 6
    ":status" => 8
    "accept-encoding" => 16
    "accept" => 19
    "authorization" => 23
    "cache-control" => 24
    "content-encoding" => 26
    "content-length" => 28
    "content-type" => 31
    "cookie" => 32
    "host" => 38
    "location" => 46
    "set-cookie" => 55
    "user-agent" => 58
    _ => 0
  }
}

///|
#cfg(target="native")
fn hpack_write_int(
  out : @buffer.Buffer,
  value : Int,
  prefix_bits~ : Int,
  first_mask~ : Int,
) -> Unit {
  let max_prefix = (1 << prefix_bits) - 1
  if value < max_prefix {
    out.write_byte((first_mask | value).to_byte())
  } else {
    out.write_byte((first_mask | max_prefix).to_byte())
    for remaining = value - max_prefix {
      if remaining >= 128 {
        out.write_byte(((remaining % 128) | 128).to_byte())
        continue remaining / 128
      } else {
        out.write_byte(remaining.to_byte())
        break
      }
    }
  }
}

///|
#cfg(target="native")
fn hpack_read_int(
  data : Bytes,
  offset : Int,
  prefix_bits~ : Int,
) -> (Int, Int) raise {
  guard offset < data.length() else { raise HpackBadInteger }
  let mask = (1 << prefix_bits) - 1
  let first = data[offset].to_int() & mask
  if first < mask {
    (first, offset + 1)
  } else {
    let mut value = mask
    let mut shift = 0
    let mut pos = offset + 1
    for ;; {
      guard pos < data.length() else { raise HpackBadInteger }
      let b = data[pos].to_int()
      value += (b & 0x7f) << shift
      pos += 1
      if (b & 0x80) == 0 {
        break
      }
      shift += 7
      guard shift <= 28 else { raise HpackBadInteger }
    }
    (value, pos)
  }
}

///|
#cfg(target="native")
fn hpack_write_string(out : @buffer.Buffer, value : String) -> Unit {
  let bytes = @utf8.encode(value)
  hpack_write_int(out, bytes.length(), prefix_bits=7, first_mask=0)
  out.write_bytes(bytes)
}

///|
#cfg(target="native")
fn hpack_read_string(data : Bytes, offset : Int) -> (String, Int) raise {
  guard offset < data.length() else { raise HpackBadString }
  let is_huffman = (data[offset].to_int() & 0x80) != 0
  let (len, pos) = hpack_read_int(data, offset, prefix_bits=7)
  guard len >= 0 && pos + len <= data.length() else { raise HpackBadString }
  let raw = @buffer.new()
  raw.write_bytes(data[pos:pos + len])
  let decoded = if is_huffman {
    hpack_huffman_decode(raw.contents())
  } else {
    raw.contents()
  }
  (@utf8.decode_lossy(decoded), pos + len)
}

///|
#cfg(target="native")
fn hpack_write_header(
  out : @buffer.Buffer,
  name : String,
  value : String,
) -> Unit {
  let name = name.to_lower()
  let index = hpack_static_name_index(name)
  if index > 0 {
    hpack_write_int(out, index, prefix_bits=4, first_mask=0)
  } else {
    out.write_byte(b'\x00')
    hpack_write_string(out, name)
  }
  hpack_write_string(out, value)
}

///|
#cfg(target="native")
fn hpack_encode_headers(headers : Array[(String, String)]) -> Bytes {
  let out = @buffer.new()
  for item in headers {
    let (name, value) = item
    hpack_write_header(out, name, value)
  }
  out.contents()
}

///|
#cfg(target="native")
fn HpackDecoder::decode(
  self : HpackDecoder,
  block : Bytes,
) -> Array[(String, String)] raise {
  let headers = []
  for pos = 0; pos < block.length(); {
    let first = block[pos].to_int()
    if (first & 0x80) != 0 {
      let (index, next) = hpack_read_int(block, pos, prefix_bits=7)
      let entry = self.get(index)
      headers.push(entry)
      continue next
    } else if (first & 0x40) != 0 {
      let (name_index, pos) = hpack_read_int(block, pos, prefix_bits=6)
      let (name, pos) = if name_index == 0 {
        hpack_read_string(block, pos)
      } else {
        let (name, _) = self.get(name_index)
        (name, pos)
      }
      let (value, pos) = hpack_read_string(block, pos)
      headers.push((name, value))
      self.insert(name, value)
      continue pos
    } else if (first & 0x20) != 0 {
      let (max_size, next) = hpack_read_int(block, pos, prefix_bits=5)
      self.set_max_dynamic_size(max_size)
      continue next
    } else {
      let (name_index, pos) = hpack_read_int(block, pos, prefix_bits=4)
      let (name, pos) = if name_index == 0 {
        hpack_read_string(block, pos)
      } else {
        let (name, _) = self.get(name_index)
        (name, pos)
      }
      let (value, pos) = hpack_read_string(block, pos)
      headers.push((name, value))
      continue pos
    }
  }
  headers
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn hpack_decode_headers(block : Bytes) -> Array[(String, String)] raise {
  HpackDecoder::new().decode(block)
}
