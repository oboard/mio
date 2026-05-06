///|
#cfg(target="native")
priv suberror RsaPssError {
  RsaPssBadPublicKey
  RsaPssSignatureOutOfRange
  RsaPssVerificationFailed
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct RsaPublicKey {
  modulus : Bytes
  exponent : Int
}

///|
#cfg(target="native")
fn bigint_normalize(value : Bytes) -> Bytes {
  let mut start = 0
  while start + 1 < value.length() && value[start] == b'\x00' {
    start = start + 1
  }
  tls13_copy_slice(value, start, value.length())
}

///|
#cfg(target="native")
fn bigint_compare(a : Bytes, b : Bytes) -> Int {
  let a = bigint_normalize(a)
  let b = bigint_normalize(b)
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    for i in 0..<a.length() {
      if a[i] < b[i] {
        return -1
      } else if a[i] > b[i] {
        return 1
      }
    }
    0
  }
}

///|
#cfg(target="native")
fn bigint_add(a : Bytes, b : Bytes) -> Bytes {
  let max_len = if a.length() > b.length() { a.length() } else { b.length() }
  let out = FixedArray::make(max_len + 1, b'\x00')
  let mut carry = 0
  for i in 0..<max_len {
    let ai = if a.length() > i { a[a.length() - 1 - i].to_int() } else { 0 }
    let bi = if b.length() > i { b[b.length() - 1 - i].to_int() } else { 0 }
    let sum = ai + bi + carry
    out[max_len - i] = (sum & 0xff).to_byte()
    carry = sum >> 8
  }
  out[0] = carry.to_byte()
  bigint_normalize(out.unsafe_reinterpret_as_bytes())
}

///|
#cfg(target="native")
fn bigint_sub(a : Bytes, b : Bytes) -> Bytes raise {
  guard bigint_compare(a, b) >= 0 else { raise RsaPssBadPublicKey }
  let max_len = a.length()
  let out = FixedArray::make(max_len, b'\x00')
  let mut borrow = 0
  for i in 0..<max_len {
    let ai = a[a.length() - 1 - i].to_int()
    let bi = if b.length() > i { b[b.length() - 1 - i].to_int() } else { 0 }
    let mut diff = ai - bi - borrow
    if diff < 0 {
      diff = diff + 256
      borrow = 1
    } else {
      borrow = 0
    }
    out[max_len - 1 - i] = diff.to_byte()
  }
  bigint_normalize(out.unsafe_reinterpret_as_bytes())
}

///|
#cfg(target="native")
fn bigint_add_mod(a : Bytes, b : Bytes, modulus : Bytes) -> Bytes raise {
  let mut sum = bigint_add(a, b)
  if bigint_compare(sum, modulus) >= 0 {
    sum = bigint_sub(sum, modulus)
  }
  sum
}

///|
#cfg(target="native")
fn bigint_mul_mod(a : Bytes, b : Bytes, modulus : Bytes) -> Bytes raise {
  let mut result = b"\x00"
  let mut addend = bigint_normalize(a)
  for byte_index = b.length() - 1; byte_index >= 0; byte_index = byte_index - 1 {
    let byte = b[byte_index].to_int()
    for bit in 0..<8 {
      if ((byte >> bit) & 1) == 1 {
        result = bigint_add_mod(result, addend, modulus)
      }
      addend = bigint_add_mod(addend, addend, modulus)
    }
  }
  result
}

///|
#cfg(target="native")
fn bigint_pow_mod(base : Bytes, exponent : Int, modulus : Bytes) -> Bytes raise {
  let mut result = b"\x01"
  let mut base = bigint_normalize(base)
  let mut exponent = exponent
  while exponent > 0 {
    if (exponent & 1) == 1 {
      result = bigint_mul_mod(result, base, modulus)
    }
    exponent = exponent >> 1
    if exponent > 0 {
      base = bigint_mul_mod(base, base, modulus)
    }
  }
  result
}

///|
#cfg(target="native")
fn bigint_left_pad(value : Bytes, len : Int) -> Bytes raise {
  let value = bigint_normalize(value)
  guard value.length() <= len else { raise RsaPssBadPublicKey }
  let out = FixedArray::make(len, b'\x00')
  let start = len - value.length()
  for i in 0..<value.length() {
    out[start + i] = value[i]
  }
  out.unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
fn rsa_der_integer_bytes(data : Bytes, element : X509DerElement) -> Bytes raise {
  x509_der_expect_tag(element, 0x02)
  guard element.content_start < element.content_end else {
    raise RsaPssBadPublicKey
  }
  let value = x509_der_content(data, element)
  bigint_normalize(value)
}

///|
#cfg(target="native")
fn rsa_der_integer_int(data : Bytes, element : X509DerElement) -> Int raise {
  let value = rsa_der_integer_bytes(data, element)
  guard value.length() <= 4 else { raise RsaPssBadPublicKey }
  let mut out = 0
  for b in value {
    out = (out << 8) | b.to_int()
  }
  out
}

///|
#cfg(target="native")
fn rsa_parse_public_key(public_key : Bytes) -> RsaPublicKey raise {
  let root = x509_der_read_element(public_key, 0)
  x509_der_expect_tag(root, x509_tag_sequence)
  guard root.end == public_key.length() else { raise RsaPssBadPublicKey }
  let fields = x509_der_children(public_key, root)
  guard fields.length() >= 2 else { raise RsaPssBadPublicKey }
  {
    modulus: rsa_der_integer_bytes(public_key, fields[0]),
    exponent: rsa_der_integer_int(public_key, fields[1]),
  }
}

///|
#cfg(target="native")
fn rsa_modulus_bit_length(modulus : Bytes) -> Int raise {
  let modulus = bigint_normalize(modulus)
  guard modulus.length() > 0 else { raise RsaPssBadPublicKey }
  let first = modulus[0].to_int()
  let mut bits = 8
  while bits > 0 && ((first >> (bits - 1)) & 1) == 0 {
    bits = bits - 1
  }
  (modulus.length() - 1) * 8 + bits
}

///|
#cfg(target="native")
fn rsa_i2osp(value : Bytes, len : Int) -> Bytes raise {
  bigint_left_pad(value, len)
}

///|
#cfg(target="native")
fn rsa_public_operation(signature : Bytes, key : RsaPublicKey) -> Bytes raise {
  guard bigint_compare(signature, key.modulus) < 0 else {
    raise RsaPssSignatureOutOfRange
  }
  let value = bigint_pow_mod(signature, key.exponent, key.modulus)
  rsa_i2osp(value, key.modulus.length())
}

///|
#cfg(target="native")
fn rsa_mgf1_sha256(seed : Bytes, len : Int) -> Bytes {
  let out = @buffer.new()
  let mut counter = 0
  while out.length() < len {
    let block = @buffer.new()
    block.write_bytes(seed)
    block.write_byte(((counter >> 24) & 0xff).to_byte())
    block.write_byte(((counter >> 16) & 0xff).to_byte())
    block.write_byte(((counter >> 8) & 0xff).to_byte())
    block.write_byte((counter & 0xff).to_byte())
    out.write_bytes(tls13_sha256(block.contents()))
    counter = counter + 1
  }
  tls13_copy_slice(out.contents(), 0, len)
}

///|
#cfg(target="native")
fn rsa_pss_hash_message(message : Bytes, salt : Bytes) -> Bytes {
  let out = @buffer.new()
  out.write_bytes(Bytes::make(8, b'\x00'))
  out.write_bytes(tls13_sha256(message))
  out.write_bytes(salt)
  tls13_sha256(out.contents())
}

///|
#cfg(target="native")
fn rsa_pss_verify_encoded(
  message : Bytes,
  encoded : Bytes,
  em_bits : Int,
) -> Unit raise {
  let hash_len = 32
  let salt_len = 32
  guard encoded.length() >= hash_len + salt_len + 2 else {
    raise RsaPssVerificationFailed
  }
  guard encoded[encoded.length() - 1] == b'\xbc' else {
    raise RsaPssVerificationFailed
  }
  let db_len = encoded.length() - hash_len - 1
  let masked_db = tls13_copy_slice(encoded, 0, db_len)
  let h = tls13_copy_slice(encoded, db_len, db_len + hash_len)
  let unused_bits = encoded.length() * 8 - em_bits
  if unused_bits > 0 {
    let mask = 0xff >> unused_bits
    guard (masked_db[0].to_int() & (0xff ^ mask)) == 0 else {
      raise RsaPssVerificationFailed
    }
  }
  let db_mask = rsa_mgf1_sha256(h, db_len)
  let db = FixedArray::make(db_len, b'\x00')
  for i in 0..<db_len {
    db[i] = masked_db[i] ^ db_mask[i]
  }
  if unused_bits > 0 {
    db[0] = (db[0].to_int() & (0xff >> unused_bits)).to_byte()
  }
  let ps_len = db_len - salt_len - 1
  for i in 0..<ps_len {
    guard db[i] == b'\x00' else { raise RsaPssVerificationFailed }
  }
  guard db[ps_len] == b'\x01' else { raise RsaPssVerificationFailed }
  let salt = tls13_copy_slice(
    db.unsafe_reinterpret_as_bytes(),
    ps_len + 1,
    db_len,
  )
  let expected = rsa_pss_hash_message(message, salt)
  guard tls13_bytes_equal(expected, h) else { raise RsaPssVerificationFailed }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn rsa_pss_sha256_verify(
  public_key : Bytes,
  message : Bytes,
  signature : Bytes,
) -> Unit raise {
  let key = rsa_parse_public_key(public_key)
  let em_bits = rsa_modulus_bit_length(key.modulus) - 1
  let encoded = rsa_public_operation(signature, key)
  rsa_pss_verify_encoded(message, encoded, em_bits)
}
