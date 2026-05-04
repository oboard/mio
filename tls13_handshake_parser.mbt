///|
#cfg(target="native")
priv suberror Tls13HandshakeParseError {
  Tls13HandshakeTruncated
  Tls13UnexpectedHandshakeType
  Tls13MissingExtension
  Tls13UnsupportedKeyShare
  Tls13UnsupportedAlpn
} derive(Debug, ToJson)

///|
#cfg(target="native")
let tls13_handshake_server_hello : Int = 0x02

///|
#cfg(target="native")
let tls13_handshake_encrypted_extensions : Int = 0x08

///|
#cfg(target="native")
let tls13_handshake_certificate : Int = 0x0b

///|
#cfg(target="native")
let tls13_handshake_certificate_verify : Int = 0x0f

///|
#cfg(target="native")
let tls13_handshake_finished : Int = 0x14

///|
#cfg(target="native")
let tls13_ext_supported_versions : Int = 0x002b

///|
#cfg(target="native")
let tls13_ext_key_share : Int = 0x0033

///|
#cfg(target="native")
let tls13_ext_alpn : Int = 0x0010

///|
#cfg(target="native")
let tls13_ext_quic_transport_parameters : Int = 0x0039

///|
#cfg(target="native")
let tls13_group_x25519 : Int = 0x001d

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13Extension {
  extension_type : Int
  payload : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13ServerHello {
  random : Bytes
  legacy_session_id_echo : Bytes
  cipher_suite : Int
  compression_method : Int
  extensions : Array[Tls13Extension]
  x25519_public_key : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13EncryptedExtensions {
  extensions : Array[Tls13Extension]
  alpn : String
  transport_parameters : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13CertificateEntry {
  cert_data : Bytes
  extensions : Array[Tls13Extension]
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13Certificate {
  certificate_request_context : Bytes
  entries : Array[Tls13CertificateEntry]
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13CertificateVerify {
  signature_scheme : Int
  signature : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13Finished {
  verify_data : Bytes
}

///|
#cfg(target="native")
fn tls13_copy_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  let out = @buffer.new()
  out.write_bytes(data[start:end])
  out.contents()
}

///|
#cfg(target="native")
fn tls13_read_u16(data : Bytes, offset : Int) -> Int raise {
  guard offset + 2 <= data.length() else { raise Tls13HandshakeTruncated }
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
#cfg(target="native")
fn tls13_read_u24(data : Bytes, offset : Int) -> Int raise {
  guard offset + 3 <= data.length() else { raise Tls13HandshakeTruncated }
  (data[offset].to_int() << 16) |
  (data[offset + 1].to_int() << 8) |
  data[offset + 2].to_int()
}

///|
#cfg(target="native")
fn tls13_handshake_body(message : Bytes, expected_type : Int) -> Bytes raise {
  guard message.length() >= 4 else { raise Tls13HandshakeTruncated }
  guard message[0].to_int() == expected_type else {
    raise Tls13UnexpectedHandshakeType
  }
  let len = tls13_read_u24(message, 1)
  guard 4 + len <= message.length() else { raise Tls13HandshakeTruncated }
  tls13_copy_slice(message, 4, 4 + len)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_split_handshake_messages(data : Bytes) -> Array[Bytes] raise {
  let messages = []
  for offset = 0; offset < data.length(); {
    guard offset + 4 <= data.length() else { raise Tls13HandshakeTruncated }
    let len = tls13_read_u24(data, offset + 1)
    guard offset + 4 + len <= data.length() else {
      raise Tls13HandshakeTruncated
    }
    messages.push(tls13_copy_slice(data, offset, offset + 4 + len))
    continue offset + 4 + len
  }
  messages
}

///|
#cfg(target="native")
fn tls13_parse_extensions(
  data : Bytes,
  offset : Int,
  len : Int,
) -> Array[Tls13Extension] raise {
  guard offset + len <= data.length() else { raise Tls13HandshakeTruncated }
  let extensions = []
  for pos = offset; pos < offset + len; {
    let extension_type = tls13_read_u16(data, pos)
    let extension_len = tls13_read_u16(data, pos + 2)
    let payload_start = pos + 4
    let payload_end = payload_start + extension_len
    guard payload_end <= offset + len else { raise Tls13HandshakeTruncated }
    extensions.push({
      extension_type,
      payload: tls13_copy_slice(data, payload_start, payload_end),
    })
    continue payload_end
  }
  extensions
}

///|
#cfg(target="native")
fn tls13_find_extension(
  extensions : Array[Tls13Extension],
  extension_type : Int,
) -> Bytes raise {
  for extension in extensions {
    if extension.extension_type == extension_type {
      return extension.payload
    }
  }
  raise Tls13MissingExtension
}

///|
#cfg(target="native")
fn tls13_parse_server_key_share(payload : Bytes) -> Bytes raise {
  guard payload.length() >= 4 else { raise Tls13HandshakeTruncated }
  let group = tls13_read_u16(payload, 0)
  guard group == tls13_group_x25519 else { raise Tls13UnsupportedKeyShare }
  let key_len = tls13_read_u16(payload, 2)
  guard key_len == 32 && 4 + key_len <= payload.length() else {
    raise Tls13HandshakeTruncated
  }
  tls13_copy_slice(payload, 4, 4 + key_len)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_parse_server_hello(message : Bytes) -> Tls13ServerHello raise {
  let body = tls13_handshake_body(message, tls13_handshake_server_hello)
  guard body.length() >= 38 else { raise Tls13HandshakeTruncated }
  let random = tls13_copy_slice(body, 2, 34)
  let session_len = body[34].to_int()
  let session_start = 35
  let session_end = session_start + session_len
  guard session_end + 5 <= body.length() else { raise Tls13HandshakeTruncated }
  let cipher_suite = tls13_read_u16(body, session_end)
  let compression_method = body[session_end + 2].to_int()
  let extensions_len = tls13_read_u16(body, session_end + 3)
  let extensions = tls13_parse_extensions(body, session_end + 5, extensions_len)
  let version = tls13_find_extension(extensions, tls13_ext_supported_versions)
  guard version == b"\x03\x04" else { raise Tls13UnexpectedHandshakeType }
  {
    random,
    legacy_session_id_echo: tls13_copy_slice(body, session_start, session_end),
    cipher_suite,
    compression_method,
    extensions,
    x25519_public_key: tls13_parse_server_key_share(
      tls13_find_extension(extensions, tls13_ext_key_share),
    ),
  }
}

///|
#cfg(target="native")
fn tls13_parse_alpn(payload : Bytes) -> String raise {
  guard payload.length() >= 3 else { raise Tls13HandshakeTruncated }
  let list_len = tls13_read_u16(payload, 0)
  guard list_len + 2 <= payload.length() else { raise Tls13HandshakeTruncated }
  let proto_len = payload[2].to_int()
  guard proto_len + 3 <= payload.length() else { raise Tls13HandshakeTruncated }
  let proto = @utf8.decode_lossy(payload[3:3 + proto_len])
  guard proto == "h3" else { raise Tls13UnsupportedAlpn }
  proto
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_parse_encrypted_extensions(
  message : Bytes,
) -> Tls13EncryptedExtensions raise {
  let body = tls13_handshake_body(message, tls13_handshake_encrypted_extensions)
  guard body.length() >= 2 else { raise Tls13HandshakeTruncated }
  let extensions_len = tls13_read_u16(body, 0)
  let extensions = tls13_parse_extensions(body, 2, extensions_len)
  {
    extensions,
    alpn: tls13_parse_alpn(tls13_find_extension(extensions, tls13_ext_alpn)),
    transport_parameters: tls13_find_extension(
      extensions, tls13_ext_quic_transport_parameters,
    ),
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_parse_certificate(message : Bytes) -> Tls13Certificate raise {
  let body = tls13_handshake_body(message, tls13_handshake_certificate)
  guard body.length() >= 4 else { raise Tls13HandshakeTruncated }
  let context_len = body[0].to_int()
  let context_start = 1
  let context_end = context_start + context_len
  guard context_end + 3 <= body.length() else { raise Tls13HandshakeTruncated }
  let list_len = tls13_read_u24(body, context_end)
  let mut pos = context_end + 3
  let end = pos + list_len
  guard end <= body.length() else { raise Tls13HandshakeTruncated }
  let entries = []
  while pos < end {
    let cert_len = tls13_read_u24(body, pos)
    let cert_start = pos + 3
    let cert_end = cert_start + cert_len
    guard cert_end + 2 <= end else { raise Tls13HandshakeTruncated }
    let extensions_len = tls13_read_u16(body, cert_end)
    let extensions_start = cert_end + 2
    let extensions_end = extensions_start + extensions_len
    guard extensions_end <= end else { raise Tls13HandshakeTruncated }
    entries.push({
      cert_data: tls13_copy_slice(body, cert_start, cert_end),
      extensions: tls13_parse_extensions(body, extensions_start, extensions_len),
    })
    pos = extensions_end
  }
  {
    certificate_request_context: tls13_copy_slice(
      body, context_start, context_end,
    ),
    entries,
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_parse_certificate_verify(
  message : Bytes,
) -> Tls13CertificateVerify raise {
  let body = tls13_handshake_body(message, tls13_handshake_certificate_verify)
  guard body.length() >= 4 else { raise Tls13HandshakeTruncated }
  let signature_scheme = tls13_read_u16(body, 0)
  let signature_len = tls13_read_u16(body, 2)
  guard 4 + signature_len <= body.length() else {
    raise Tls13HandshakeTruncated
  }
  { signature_scheme, signature: tls13_copy_slice(body, 4, 4 + signature_len) }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_certificate_verify_input(
  context : String,
  transcript_hash : Bytes,
) -> Bytes {
  let out = @buffer.new()
  for _ in 0..<64 {
    out.write_byte(b'\x20')
  }
  out.write_bytes(@utf8.encode(context))
  out.write_byte(b'\x00')
  out.write_bytes(transcript_hash)
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_parse_finished(message : Bytes) -> Tls13Finished raise {
  let body = tls13_handshake_body(message, tls13_handshake_finished)
  { verify_data: body }
}
