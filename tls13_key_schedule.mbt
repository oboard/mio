///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13HandshakeSecrets {
  early_secret : Bytes
  derived_secret : Bytes
  handshake_secret : Bytes
  client_handshake_traffic_secret : Bytes
  server_handshake_traffic_secret : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13TrafficKeys {
  key : Bytes
  iv : Bytes
  finished_key : Bytes
}

///|
#cfg(target="native")
fn tls13_sha256(data : Bytes) -> Bytes {
  @crypto.sha256(data).unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_transcript_hash(messages : Array[Bytes]) -> Bytes {
  let out = @buffer.new()
  for message in messages {
    out.write_bytes(message)
  }
  tls13_sha256(out.contents())
}

///|
#cfg(target="native")
fn tls13_empty_hash() -> Bytes {
  tls13_sha256(b"")
}

///|
#cfg(target="native")
fn tls13_zeros() -> Bytes {
  Bytes::make(32, b'\x00')
}

///|
#cfg(target="native")
fn tls13_derive_secret(
  secret : Bytes,
  label : String,
  transcript_hash : Bytes,
) -> Bytes raise {
  quic_hkdf_expand_label(secret, label, transcript_hash, 32)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_derive_handshake_secrets(
  shared_secret : Bytes,
  transcript_hash : Bytes,
) -> Tls13HandshakeSecrets raise {
  let early_secret = quic_hkdf_extract(tls13_zeros(), b"")
  let derived_secret = tls13_derive_secret(
    early_secret,
    "derived",
    tls13_empty_hash(),
  )
  let handshake_secret = quic_hkdf_extract(derived_secret, shared_secret)
  {
    early_secret,
    derived_secret,
    handshake_secret,
    client_handshake_traffic_secret: tls13_derive_secret(
      handshake_secret, "c hs traffic", transcript_hash,
    ),
    server_handshake_traffic_secret: tls13_derive_secret(
      handshake_secret, "s hs traffic", transcript_hash,
    ),
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_derive_traffic_keys(secret : Bytes) -> Tls13TrafficKeys raise {
  {
    key: quic_hkdf_expand_label(secret, "key", b"", 16),
    iv: quic_hkdf_expand_label(secret, "iv", b"", 12),
    finished_key: quic_hkdf_expand_label(secret, "finished", b"", 32),
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_finished_verify_data(
  finished_key : Bytes,
  transcript_hash : Bytes,
) -> Bytes {
  @crypto.hmac(@crypto.SHA256::new(), finished_key, transcript_hash).unsafe_reinterpret_as_bytes()
}
