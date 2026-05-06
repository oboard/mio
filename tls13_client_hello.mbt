///|
#cfg(target="native")
priv suberror Tls13ClientHelloError {
  Tls13BadRandomLength
  Tls13BadSessionIdLength
  Tls13BadKeyShareLength
  Tls13VectorTooLarge
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-struct_never_constructed")
priv struct Tls13ClientHelloConfig {
  server_name : String
  alpn : String
  random : Bytes
  legacy_session_id : Bytes
  x25519_public_key : Bytes
  transport_parameters : Bytes
}

///|
#cfg(target="native")
fn tls13_write_u16(out : @buffer.Buffer, value : Int) -> Unit raise {
  guard value >= 0 && value <= 0xffff else { raise Tls13VectorTooLarge }
  out.write_byte(((value >> 8) & 0xff).to_byte())
  out.write_byte((value & 0xff).to_byte())
}

///|
#cfg(target="native")
fn tls13_write_u24(out : @buffer.Buffer, value : Int) -> Unit raise {
  guard value >= 0 && value <= 0xffffff else { raise Tls13VectorTooLarge }
  out.write_byte(((value >> 16) & 0xff).to_byte())
  out.write_byte(((value >> 8) & 0xff).to_byte())
  out.write_byte((value & 0xff).to_byte())
}

///|
#cfg(target="native")
fn tls13_extension(extension_type : Int, payload : Bytes) -> Bytes raise {
  let out = @buffer.new()
  tls13_write_u16(out, extension_type)
  tls13_write_u16(out, payload.length())
  out.write_bytes(payload)
  out.contents()
}

///|
#cfg(target="native")
fn tls13_server_name_extension(server_name : String) -> Bytes raise {
  let name = @utf8.encode(server_name)
  let list = @buffer.new()
  list.write_byte(b'\x00')
  tls13_write_u16(list, name.length())
  list.write_bytes(name)
  let payload = @buffer.new()
  tls13_write_u16(payload, list.length())
  payload.write_bytes(list.contents())
  tls13_extension(0x0000, payload.contents())
}

///|
#cfg(target="native")
fn tls13_alpn_extension(alpn : String) -> Bytes raise {
  let protocol = @utf8.encode(alpn)
  guard protocol.length() <= 255 else { raise Tls13VectorTooLarge }
  let list = @buffer.new()
  list.write_byte(protocol.length().to_byte())
  list.write_bytes(protocol)
  let payload = @buffer.new()
  tls13_write_u16(payload, list.length())
  payload.write_bytes(list.contents())
  tls13_extension(0x0010, payload.contents())
}

///|
#cfg(target="native")
fn tls13_supported_groups_extension() -> Bytes raise {
  let payload = @buffer.new()
  tls13_write_u16(payload, 2)
  tls13_write_u16(payload, 0x001d)
  tls13_extension(0x000a, payload.contents())
}

///|
#cfg(target="native")
fn tls13_signature_algorithms_extension() -> Bytes raise {
  let payload = @buffer.new()
  tls13_write_u16(payload, 2)
  tls13_write_u16(payload, tls13_signature_rsa_pss_rsae_sha256)
  tls13_extension(0x000d, payload.contents())
}

///|
#cfg(target="native")
fn tls13_supported_versions_extension() -> Bytes raise {
  let payload = @buffer.new()
  payload.write_byte(b'\x02')
  tls13_write_u16(payload, 0x0304)
  tls13_extension(0x002b, payload.contents())
}

///|
#cfg(target="native")
fn tls13_psk_modes_extension() -> Bytes raise {
  tls13_extension(0x002d, b"\x01\x01")
}

///|
#cfg(target="native")
fn tls13_key_share_extension(public_key : Bytes) -> Bytes raise {
  guard public_key.length() == 32 else { raise Tls13BadKeyShareLength }
  let entry = @buffer.new()
  tls13_write_u16(entry, 0x001d)
  tls13_write_u16(entry, public_key.length())
  entry.write_bytes(public_key)
  let payload = @buffer.new()
  tls13_write_u16(payload, entry.length())
  payload.write_bytes(entry.contents())
  tls13_extension(0x0033, payload.contents())
}

///|
#cfg(target="native")
fn tls13_quic_transport_parameters_extension(parameters : Bytes) -> Bytes raise {
  tls13_extension(0x0039, parameters)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_encode_client_hello(config : Tls13ClientHelloConfig) -> Bytes raise {
  guard config.random.length() == 32 else { raise Tls13BadRandomLength }
  guard config.legacy_session_id.length() <= 32 else {
    raise Tls13BadSessionIdLength
  }
  let extensions = @buffer.new()
  extensions.write_bytes(tls13_server_name_extension(config.server_name))
  extensions.write_bytes(tls13_supported_groups_extension())
  extensions.write_bytes(tls13_signature_algorithms_extension())
  extensions.write_bytes(tls13_supported_versions_extension())
  extensions.write_bytes(tls13_psk_modes_extension())
  extensions.write_bytes(tls13_key_share_extension(config.x25519_public_key))
  extensions.write_bytes(tls13_alpn_extension(config.alpn))
  extensions.write_bytes(
    tls13_quic_transport_parameters_extension(config.transport_parameters),
  )
  let body = @buffer.new()
  tls13_write_u16(body, 0x0303)
  body.write_bytes(config.random)
  body.write_byte(config.legacy_session_id.length().to_byte())
  body.write_bytes(config.legacy_session_id)
  tls13_write_u16(body, 2)
  tls13_write_u16(body, 0x1301)
  body.write_byte(b'\x01')
  body.write_byte(b'\x00')
  tls13_write_u16(body, extensions.length())
  body.write_bytes(extensions.contents())
  let body = body.contents()
  let out = @buffer.new()
  out.write_byte(b'\x01')
  tls13_write_u24(out, body.length())
  out.write_bytes(body)
  out.contents()
}
