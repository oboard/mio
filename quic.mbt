///|
#cfg(target="native")
priv suberror QuicCodecError {
  QuicVarIntTooLarge
  QuicVarIntTruncated
  QuicPacketTooShort
} derive(Debug, ToJson)

///|
#cfg(target="native")
fn quic_write_varint(out : @buffer.Buffer, value : Int) -> Unit raise {
  guard value >= 0 else { raise QuicVarIntTooLarge }
  if value < 64 {
    out.write_byte(value.to_byte())
  } else if value < 16384 {
    out.write_byte(((value >> 8) | 0x40).to_byte())
    out.write_byte((value & 0xff).to_byte())
  } else if value < 1073741824 {
    out.write_byte(((value >> 24) | 0x80).to_byte())
    out.write_byte(((value >> 16) & 0xff).to_byte())
    out.write_byte(((value >> 8) & 0xff).to_byte())
    out.write_byte((value & 0xff).to_byte())
  } else {
    raise QuicVarIntTooLarge
  }
}

///|
#cfg(target="native")
fn quic_read_varint(data : Bytes, offset : Int) -> (Int, Int) raise {
  guard offset < data.length() else { raise QuicVarIntTruncated }
  let first = data[offset].to_int()
  match first >> 6 {
    0 => (first & 0x3f, offset + 1)
    1 => {
      guard offset + 2 <= data.length() else { raise QuicVarIntTruncated }
      let value = ((first & 0x3f) << 8) | data[offset + 1].to_int()
      (value, offset + 2)
    }
    2 => {
      guard offset + 4 <= data.length() else { raise QuicVarIntTruncated }
      let value = ((first & 0x3f) << 24) |
        (data[offset + 1].to_int() << 16) |
        (data[offset + 2].to_int() << 8) |
        data[offset + 3].to_int()
      (value, offset + 4)
    }
    _ => raise QuicVarIntTooLarge
  }
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicLongHeader {
  packet_type : Int
  version : Int
  destination_connection_id : Bytes
  source_connection_id : Bytes
  payload_offset : Int
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_parse_long_header(packet : Bytes) -> QuicLongHeader raise {
  guard packet.length() >= 7 else { raise QuicPacketTooShort }
  let first = packet[0].to_int()
  guard (first & 0x80) != 0 else { raise QuicPacketTooShort }
  let version = (packet[1].to_int() << 24) |
    (packet[2].to_int() << 16) |
    (packet[3].to_int() << 8) |
    packet[4].to_int()
  let dcid_len = packet[5].to_int()
  guard 6 + dcid_len < packet.length() else { raise QuicPacketTooShort }
  let dcid = @buffer.new()
  dcid.write_bytes(packet[6:6 + dcid_len])
  let scid_len_pos = 6 + dcid_len
  let scid_len = packet[scid_len_pos].to_int()
  let scid_start = scid_len_pos + 1
  guard scid_start + scid_len <= packet.length() else {
    raise QuicPacketTooShort
  }
  let scid = @buffer.new()
  scid.write_bytes(packet[scid_start:scid_start + scid_len])
  {
    packet_type: (first >> 4) & 0x3,
    version,
    destination_connection_id: dcid.contents(),
    source_connection_id: scid.contents(),
    payload_offset: scid_start + scid_len,
  }
}
