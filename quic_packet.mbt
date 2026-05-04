///|
#cfg(target="native")
priv suberror QuicPacketProtectionError {
  QuicPacketNumberTooLarge
  QuicPacketNumberLengthInvalid
  QuicProtectedPayloadTooShort
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicProtectedPacket {
  packet : Bytes
  header_length : Int
  packet_number_offset : Int
  packet_number_length : Int
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicInitialPacket {
  destination_connection_id : Bytes
  source_connection_id : Bytes
  token : Bytes
  packet_number : Int
  payload : Bytes
}

///|
#cfg(target="native")
fn quic_copy_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  let out = @buffer.new()
  out.write_bytes(data[start:end])
  out.contents()
}

///|
#cfg(target="native")
fn quic_packet_number_len(packet_number : Int) -> Int raise {
  guard packet_number >= 0 else { raise QuicPacketNumberTooLarge }
  if packet_number <= 0xff {
    1
  } else if packet_number <= 0xffff {
    2
  } else if packet_number <= 0xffffff {
    3
  } else if packet_number <= 0x3fffffff {
    4
  } else {
    raise QuicPacketNumberTooLarge
  }
}

///|
#cfg(target="native")
fn quic_write_packet_number(
  out : @buffer.Buffer,
  packet_number : Int,
  len : Int,
) -> Unit raise {
  guard len >= 1 && len <= 4 else { raise QuicPacketNumberLengthInvalid }
  for i in 0..<len {
    let shift = (len - i - 1) * 8
    out.write_byte(((packet_number >> shift) & 0xff).to_byte())
  }
}

///|
#cfg(target="native")
fn quic_read_packet_number(data : Bytes, offset : Int, len : Int) -> Int raise {
  guard len >= 1 && len <= 4 else { raise QuicPacketNumberLengthInvalid }
  guard offset + len <= data.length() else { raise QuicPacketTooShort }
  let mut packet_number = 0
  for i in 0..<len {
    packet_number = (packet_number << 8) | data[offset + i].to_int()
  }
  packet_number
}

///|
#cfg(target="native")
fn quic_initial_nonce(iv : Bytes, packet_number : Int) -> Bytes raise {
  guard packet_number >= 0 else { raise QuicPacketNumberTooLarge }
  guard iv.length() == 12 else { raise AesBadNonceLength }
  let nonce = FixedArray::make(12, b'\x00')
  for i in 0..<12 {
    nonce[i] = iv[i]
  }
  for i in 0..<8 {
    let shift = (7 - i) * 8
    nonce[4 + i] = nonce[4 + i] ^ ((packet_number >> shift) & 0xff).to_byte()
  }
  nonce.unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
fn quic_build_initial_header(
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  token : Bytes,
  packet_number : Int,
  protected_payload_length : Int,
) -> (Bytes, Int, Int) raise {
  let packet_number_length = quic_packet_number_len(packet_number)
  let out = @buffer.new()
  out.write_byte((0xc0 | ((packet_number_length - 1) & 0x03)).to_byte())
  out.write_byte(b'\x00')
  out.write_byte(b'\x00')
  out.write_byte(b'\x00')
  out.write_byte(b'\x01')
  out.write_byte(destination_connection_id.length().to_byte())
  out.write_bytes(destination_connection_id)
  out.write_byte(source_connection_id.length().to_byte())
  out.write_bytes(source_connection_id)
  quic_write_varint(out, token.length())
  out.write_bytes(token)
  quic_write_varint(out, packet_number_length + protected_payload_length)
  let packet_number_offset = out.length()
  quic_write_packet_number(out, packet_number, packet_number_length)
  (out.contents(), packet_number_offset, packet_number_length)
}

///|
#cfg(target="native")
fn quic_apply_initial_header_protection(
  packet : Bytes,
  header_protection_key : Bytes,
  packet_number_offset : Int,
  packet_number_length : Int,
) -> Bytes raise {
  let sample_offset = packet_number_offset + 4
  guard sample_offset + 16 <= packet.length() else {
    raise QuicProtectedPayloadTooShort
  }
  let mask = aes128_encrypt_block(
    header_protection_key,
    quic_copy_slice(packet, sample_offset, sample_offset + 16),
  )
  let out = FixedArray::make(packet.length(), b'\x00')
  for i in 0..<packet.length() {
    out[i] = packet[i]
  }
  out[0] = out[0] ^ (mask[0] & b'\x0f')
  for i in 0..<packet_number_length {
    out[packet_number_offset + i] = out[packet_number_offset + i] ^ mask[1 + i]
  }
  out.unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
fn quic_remove_initial_header_protection(
  packet : Bytes,
  header_protection_key : Bytes,
  packet_number_offset : Int,
) -> (Bytes, Int) raise {
  let sample_offset = packet_number_offset + 4
  guard sample_offset + 16 <= packet.length() else {
    raise QuicProtectedPayloadTooShort
  }
  let mask = aes128_encrypt_block(
    header_protection_key,
    quic_copy_slice(packet, sample_offset, sample_offset + 16),
  )
  let packet_number_length = ((packet[0] ^ (mask[0] & b'\x0f')).to_int() & 0x03) +
    1
  let out = FixedArray::make(packet.length(), b'\x00')
  for i in 0..<packet.length() {
    out[i] = packet[i]
  }
  out[0] = out[0] ^ (mask[0] & b'\x0f')
  for i in 0..<packet_number_length {
    out[packet_number_offset + i] = out[packet_number_offset + i] ^ mask[1 + i]
  }
  (out.unsafe_reinterpret_as_bytes(), packet_number_length)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_client_initial_packet(
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  token : Bytes,
  packet_number : Int,
  payload : Bytes,
) -> QuicProtectedPacket raise {
  quic_build_initial_packet(
    destination_connection_id,
    source_connection_id,
    token,
    packet_number,
    payload,
    quic_initial_packet_keys(destination_connection_id, QuicClientInitial),
  )
}

///|
#cfg(target="native")
fn quic_build_initial_packet(
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  token : Bytes,
  packet_number : Int,
  payload : Bytes,
  keys : QuicPacketKeys,
) -> QuicProtectedPacket raise {
  let protected_payload_length = payload.length() + 16
  let (header, packet_number_offset, packet_number_length) = quic_build_initial_header(
    destination_connection_id, source_connection_id, token, packet_number, protected_payload_length,
  )
  let nonce = quic_initial_nonce(keys.iv, packet_number)
  let result = aes128_gcm_encrypt(keys.key, nonce, payload, header)
  let unprotected = @buffer.new()
  unprotected.write_bytes(header)
  unprotected.write_bytes(result.ciphertext)
  unprotected.write_bytes(result.tag)
  let packet = quic_apply_initial_header_protection(
    unprotected.contents(),
    keys.hp,
    packet_number_offset,
    packet_number_length,
  )
  {
    packet,
    header_length: header.length(),
    packet_number_offset,
    packet_number_length,
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_server_initial_packet(
  original_destination_connection_id : Bytes,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  packet_number : Int,
  payload : Bytes,
) -> QuicProtectedPacket raise {
  quic_build_initial_packet(
    destination_connection_id,
    source_connection_id,
    b"",
    packet_number,
    payload,
    quic_initial_packet_keys(
      original_destination_connection_id,
      QuicServerInitial,
    ),
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_build_client_initial_datagram(
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  packet_number : Int,
  crypto_data : Bytes,
) -> QuicProtectedPacket raise {
  let crypto_frame = quic_encode_crypto_frame(0, crypto_data)
  let mut payload = crypto_frame
  let mut packet = quic_build_client_initial_packet(
    destination_connection_id, source_connection_id, b"", packet_number, payload,
  )
  while packet.packet.length() < 1200 {
    let padded = @buffer.new()
    padded.write_bytes(payload)
    padded.write_bytes(quic_encode_padding(1200 - packet.packet.length()))
    payload = padded.contents()
    packet = quic_build_client_initial_packet(
      destination_connection_id, source_connection_id, b"", packet_number, payload,
    )
  }
  packet
}

///|
#cfg(target="native")
fn quic_initial_packet_number_offset(packet : Bytes) -> (Int, Int, Int) raise {
  let long_header = quic_parse_long_header(packet)
  guard long_header.packet_type == 0 else { raise QuicPacketTooShort }
  let (token_length, token_start) = quic_read_varint(
    packet,
    long_header.payload_offset,
  )
  let length_offset = token_start + token_length
  let (payload_length, packet_number_offset) = quic_read_varint(
    packet, length_offset,
  )
  (payload_length, packet_number_offset, token_start)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_open_client_initial_packet(
  packet : Bytes,
  original_destination_connection_id : Bytes,
) -> QuicInitialPacket raise {
  quic_open_initial_packet(
    packet,
    quic_initial_packet_keys(
      original_destination_connection_id,
      QuicClientInitial,
    ),
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_open_server_initial_packet(
  packet : Bytes,
  original_destination_connection_id : Bytes,
) -> QuicInitialPacket raise {
  quic_open_initial_packet(
    packet,
    quic_initial_packet_keys(
      original_destination_connection_id,
      QuicServerInitial,
    ),
  )
}

///|
#cfg(target="native")
fn quic_open_initial_packet(
  packet : Bytes,
  keys : QuicPacketKeys,
) -> QuicInitialPacket raise {
  let (_, packet_number_offset, _) = quic_initial_packet_number_offset(packet)
  let (unprotected, packet_number_length) = quic_remove_initial_header_protection(
    packet,
    keys.hp,
    packet_number_offset,
  )
  let long_header = quic_parse_long_header(unprotected)
  let (token_length, token_payload_start) = quic_read_varint(
    unprotected,
    long_header.payload_offset,
  )
  let token = @buffer.new()
  token.write_bytes(
    unprotected[token_payload_start:token_payload_start + token_length],
  )
  let (payload_length, packet_number_offset) = quic_read_varint(
    unprotected,
    token_payload_start + token_length,
  )
  let packet_number = quic_read_packet_number(
    unprotected, packet_number_offset, packet_number_length,
  )
  let encrypted_offset = packet_number_offset + packet_number_length
  let encrypted_length = payload_length - packet_number_length
  guard encrypted_length >= 16 else { raise QuicProtectedPayloadTooShort }
  guard encrypted_offset + encrypted_length <= unprotected.length() else {
    raise QuicPacketTooShort
  }
  let ciphertext_length = encrypted_length - 16
  let ciphertext = quic_copy_slice(
    unprotected,
    encrypted_offset,
    encrypted_offset + ciphertext_length,
  )
  let tag = quic_copy_slice(
    unprotected,
    encrypted_offset + ciphertext_length,
    encrypted_offset + encrypted_length,
  )
  let nonce = quic_initial_nonce(keys.iv, packet_number)
  let plaintext = aes128_gcm_decrypt(
    keys.key,
    nonce,
    ciphertext,
    quic_copy_slice(unprotected, 0, encrypted_offset),
    tag,
  )
  {
    destination_connection_id: long_header.destination_connection_id,
    source_connection_id: long_header.source_connection_id,
    token: token.contents(),
    packet_number,
    payload: plaintext,
  }
}
