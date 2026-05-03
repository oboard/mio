///|
#cfg(target="native")
priv suberror QuicCryptoError {
  BadHex
  HkdfOutputTooLarge
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicInitialSecrets {
  initial_secret : Bytes
  client_initial_secret : Bytes
  server_initial_secret : Bytes
}

///|
#cfg(target="native")
fn hex_value(c : UInt16) -> Int raise {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    raise BadHex
  }
}

///|
#cfg(target="native")
fn bytes_from_hex(hex : String) -> Bytes raise {
  guard hex.length() % 2 == 0 else { raise BadHex }
  let out = @buffer.new()
  for i = 0; i < hex.length(); i = i + 2 {
    let hi = hex_value(hex.code_unit_at(i))
    let lo = hex_value(hex.code_unit_at(i + 1))
    out.write_byte(((hi << 4) | lo).to_byte())
  }
  out.contents()
}

///|
#cfg(target="native")
fn quic_hkdf_extract(salt : Bytes, ikm : Bytes) -> Bytes {
  @crypto.hmac(@crypto.SHA256::new(), salt, ikm).unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
fn quic_hkdf_expand(prk : Bytes, info : Bytes, len : Int) -> Bytes raise {
  guard len <= 8160 else { raise HkdfOutputTooLarge }
  let out = @buffer.new()
  let mut previous = b""
  for counter = 1; out.length() < len; counter = counter + 1 {
    let msg = @buffer.new()
    msg.write_bytes(previous)
    msg.write_bytes(info)
    msg.write_byte(counter.to_byte())
    previous = @crypto.hmac(@crypto.SHA256::new(), prk, msg.contents()).unsafe_reinterpret_as_bytes()
    let remaining = len - out.length()
    out.write_bytes(previous[:@cmp.minimum(remaining, previous.length())])
  }
  out.contents()
}

///|
#cfg(target="native")
fn quic_hkdf_expand_label(
  secret : Bytes,
  label : String,
  context : Bytes,
  len : Int,
) -> Bytes raise {
  let full_label = "tls13 \{label}"
  let label_bytes = @utf8.encode(full_label)
  let info = @buffer.new()
  info.write_byte(((len >> 8) & 0xff).to_byte())
  info.write_byte((len & 0xff).to_byte())
  info.write_byte(label_bytes.length().to_byte())
  info.write_bytes(label_bytes)
  info.write_byte(context.length().to_byte())
  info.write_bytes(context)
  quic_hkdf_expand(secret, info.contents(), len)
}

///|
#cfg(target="native")
fn quic_v1_initial_salt() -> Bytes {
  bytes_from_hex("38762cf7f55934b34d179ae6a4c80cadccbb7f0a") catch {
    _ => abort("invalid QUIC v1 salt")
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_initial_secrets(dcid : Bytes) -> QuicInitialSecrets raise {
  let initial_secret = quic_hkdf_extract(quic_v1_initial_salt(), dcid)
  {
    initial_secret,
    client_initial_secret: quic_hkdf_expand_label(
      initial_secret, "client in", b"", 32,
    ),
    server_initial_secret: quic_hkdf_expand_label(
      initial_secret, "server in", b"", 32,
    ),
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_initial_key(secret : Bytes) -> Bytes raise {
  quic_hkdf_expand_label(secret, "quic key", b"", 16)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_initial_iv(secret : Bytes) -> Bytes raise {
  quic_hkdf_expand_label(secret, "quic iv", b"", 12)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_initial_hp(secret : Bytes) -> Bytes raise {
  quic_hkdf_expand_label(secret, "quic hp", b"", 16)
}
