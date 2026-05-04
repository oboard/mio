///|
#cfg(target="native")
priv suberror Tls13HandshakeStateError {
  Tls13FinishedVerifyFailed
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13ServerHandshakeResult {
  server_hello : Tls13ServerHello
  encrypted_extensions : Tls13EncryptedExtensions
  handshake_secrets : Tls13HandshakeSecrets
  server_handshake_keys : Tls13TrafficKeys
}

///|
#cfg(target="native")
fn tls13_bytes_equal(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    false
  } else {
    let mut same = true
    for i in 0..<a.length() {
      same = same && a[i] == b[i]
    }
    same
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn tls13_process_server_handshake(
  client_private_key : Bytes,
  client_hello : Bytes,
  server_hello_message : Bytes,
  encrypted_extensions_message : Bytes,
  finished_message : Bytes,
  extra_messages_before_finished? : Array[Bytes] = [],
) -> Tls13ServerHandshakeResult raise {
  let server_hello = tls13_parse_server_hello(server_hello_message)
  let shared_secret = x25519(client_private_key, server_hello.x25519_public_key)
  let handshake_transcript = tls13_transcript_hash([
    client_hello, server_hello_message,
  ])
  let handshake_secrets = tls13_derive_handshake_secrets(
    shared_secret, handshake_transcript,
  )
  let server_handshake_keys = tls13_derive_traffic_keys(
    handshake_secrets.server_handshake_traffic_secret,
  )
  let encrypted_extensions = tls13_parse_encrypted_extensions(
    encrypted_extensions_message,
  )
  let before_finished = @buffer.new()
  before_finished.write_bytes(client_hello)
  before_finished.write_bytes(server_hello_message)
  before_finished.write_bytes(encrypted_extensions_message)
  for message in extra_messages_before_finished {
    before_finished.write_bytes(message)
  }
  let finished_transcript = tls13_sha256(before_finished.contents())
  let expected = tls13_finished_verify_data(
    server_handshake_keys.finished_key,
    finished_transcript,
  )
  let finished = tls13_parse_finished(finished_message)
  guard tls13_bytes_equal(expected, finished.verify_data) else {
    raise Tls13FinishedVerifyFailed
  }
  {
    server_hello,
    encrypted_extensions,
    handshake_secrets,
    server_handshake_keys,
  }
}
