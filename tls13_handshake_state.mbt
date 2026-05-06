///|
#cfg(target="native")
priv suberror Tls13HandshakeStateError {
  Tls13FinishedVerifyFailed
  Tls13UnsupportedSignatureScheme
} derive(Debug, ToJson)

///|
#cfg(target="native")
let tls13_signature_rsa_pss_rsae_sha256 : Int = 0x0804

///|
#cfg(target="native")
let tls13_oid_rsa_encryption : String = "1.2.840.113549.1.1.1"

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct Tls13ServerHandshakeResult {
  server_hello : Tls13ServerHello
  encrypted_extensions : Tls13EncryptedExtensions
  certificate : Tls13Certificate?
  peer_certificate_info : X509CertificateInfo?
  certificate_verify : Tls13CertificateVerify?
  handshake_secrets : Tls13HandshakeSecrets
  server_handshake_keys : Tls13TrafficKeys
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicTlsServerHandshakeResult {
  server_hello : Tls13ServerHello
  encrypted_extensions : Tls13EncryptedExtensions
  certificate : Tls13Certificate?
  peer_certificate_info : X509CertificateInfo?
  certificate_verify : Tls13CertificateVerify?
  handshake_secrets : Tls13HandshakeSecrets
  client_handshake_keys : Tls13TrafficKeys
  server_handshake_keys : Tls13TrafficKeys
  client_quic_handshake_keys : QuicPacketKeys
  server_quic_handshake_keys : QuicPacketKeys
  client_finished_message : Bytes
  client_quic_application_keys : QuicPacketKeys
  server_quic_application_keys : QuicPacketKeys
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
  let mut certificate = None
  let mut certificate_verify = None
  let mut certificate_verify_transcript_hash = None
  let before_finished = @buffer.new()
  before_finished.write_bytes(client_hello)
  before_finished.write_bytes(server_hello_message)
  before_finished.write_bytes(encrypted_extensions_message)
  for message in extra_messages_before_finished {
    if message.length() > 0 &&
      message[0].to_int() == tls13_handshake_certificate {
      certificate = Some(tls13_parse_certificate(message))
    } else if message.length() > 0 &&
      message[0].to_int() == tls13_handshake_certificate_verify {
      certificate_verify = Some(tls13_parse_certificate_verify(message))
      certificate_verify_transcript_hash = Some(
        tls13_sha256(before_finished.contents()),
      )
    }
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
  let peer_certificate_info = if certificate is Some(certificate) &&
    certificate.entries.length() > 0 {
    Some(x509_parse_certificate(certificate.entries[0].cert_data))
  } else {
    None
  }
  if peer_certificate_info is Some(peer_info) &&
    certificate_verify is Some(verify) &&
    certificate_verify_transcript_hash is Some(transcript_hash) {
    tls13_verify_certificate_verify(peer_info, verify, transcript_hash)
  }
  {
    server_hello,
    encrypted_extensions,
    certificate,
    peer_certificate_info,
    certificate_verify,
    handshake_secrets,
    server_handshake_keys,
  }
}

///|
#cfg(target="native")
fn tls13_verify_certificate_verify(
  peer_info : X509CertificateInfo,
  verify : Tls13CertificateVerify,
  transcript_hash : Bytes,
) -> Unit raise {
  guard verify.signature_scheme == tls13_signature_rsa_pss_rsae_sha256 &&
    peer_info.public_key_algorithm == tls13_oid_rsa_encryption else {
    raise Tls13UnsupportedSignatureScheme
  }
  rsa_pss_sha256_verify(
    peer_info.public_key,
    tls13_certificate_verify_input(
      "TLS 1.3, server CertificateVerify", transcript_hash,
    ),
    verify.signature,
  )
}

///|
#cfg(target="native")
fn tls13_encode_finished(verify_data : Bytes) -> Bytes raise {
  let out = @buffer.new()
  out.write_byte(tls13_handshake_finished.to_byte())
  tls13_write_u24(out, verify_data.length())
  out.write_bytes(verify_data)
  out.contents()
}

///|
#cfg(target="native")
fn tls13_build_client_finished(
  handshake_secrets : Tls13HandshakeSecrets,
  transcript_through_server_finished : Bytes,
) -> (Tls13TrafficKeys, Bytes) raise {
  let client_handshake_keys = tls13_derive_traffic_keys(
    handshake_secrets.client_handshake_traffic_secret,
  )
  let verify_data = tls13_finished_verify_data(
    client_handshake_keys.finished_key,
    transcript_through_server_finished,
  )
  (client_handshake_keys, tls13_encode_finished(verify_data))
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_process_tls13_server_handshake(
  client_private_key : Bytes,
  client_hello : Bytes,
  original_destination_connection_id : Bytes,
  server_initial_packet : Bytes,
  server_handshake_packets : Array[Bytes],
) -> QuicTlsServerHandshakeResult raise {
  let initial = quic_open_server_initial_packet(
    server_initial_packet, original_destination_connection_id,
  )
  let initial_crypto = quic_collect_crypto_data(initial.payload)
  let server_hello_messages = tls13_split_handshake_messages(initial_crypto)
  guard server_hello_messages.length() >= 1 else {
    raise Tls13HandshakeTruncated
  }
  let server_hello_message = server_hello_messages[0]
  let server_hello = tls13_parse_server_hello(server_hello_message)
  let shared_secret = x25519(client_private_key, server_hello.x25519_public_key)
  let handshake_secrets = tls13_derive_handshake_secrets(
    shared_secret,
    tls13_transcript_hash([client_hello, server_hello_message]),
  )
  let server_quic_handshake_keys = tls13_derive_quic_packet_keys(
    handshake_secrets.server_handshake_traffic_secret,
  )
  let handshake_crypto = @buffer.new()
  for packet in server_handshake_packets {
    let opened = quic_open_handshake_packet(packet, server_quic_handshake_keys)
    handshake_crypto.write_bytes(quic_collect_crypto_data(opened.payload))
  }
  let handshake_messages = tls13_split_handshake_messages(
    handshake_crypto.contents(),
  )
  guard handshake_messages.length() >= 2 else { raise Tls13HandshakeTruncated }
  let encrypted_extensions_message = handshake_messages[0]
  let finished_message = handshake_messages[handshake_messages.length() - 1]
  let extra_messages = []
  for i in 1..<(handshake_messages.length() - 1) {
    extra_messages.push(handshake_messages[i])
  }
  let verified = tls13_process_server_handshake(
    client_private_key,
    client_hello,
    server_hello_message,
    encrypted_extensions_message,
    finished_message,
    extra_messages_before_finished=extra_messages,
  )
  let app_transcript_data = @buffer.new()
  app_transcript_data.write_bytes(client_hello)
  app_transcript_data.write_bytes(server_hello_message)
  app_transcript_data.write_bytes(handshake_crypto.contents())
  let app_transcript_hash = tls13_sha256(app_transcript_data.contents())
  let (client_handshake_keys, client_finished_message) = tls13_build_client_finished(
    handshake_secrets, app_transcript_hash,
  )
  let app_secrets = tls13_derive_application_secrets(
    handshake_secrets.handshake_secret,
    app_transcript_hash,
  )
  let client_quic_handshake_keys = tls13_derive_quic_packet_keys(
    handshake_secrets.client_handshake_traffic_secret,
  )
  {
    server_hello: verified.server_hello,
    encrypted_extensions: verified.encrypted_extensions,
    certificate: verified.certificate,
    peer_certificate_info: verified.peer_certificate_info,
    certificate_verify: verified.certificate_verify,
    handshake_secrets: verified.handshake_secrets,
    client_handshake_keys,
    server_handshake_keys: verified.server_handshake_keys,
    client_quic_handshake_keys,
    server_quic_handshake_keys,
    client_finished_message,
    client_quic_application_keys: tls13_derive_quic_packet_keys(
      app_secrets.client_application_traffic_secret,
    ),
    server_quic_application_keys: tls13_derive_quic_packet_keys(
      app_secrets.server_application_traffic_secret,
    ),
  }
}
