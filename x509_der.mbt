///|
#cfg(target="native")
priv suberror X509DerError {
  X509DerTruncated
  X509DerUnsupported
  X509DerUnexpectedTag
  X509DerMissingField
} derive(Debug, ToJson)

///|
#cfg(target="native")
let x509_tag_sequence : Int = 0x30

///|
#cfg(target="native")
let x509_tag_set : Int = 0x31

///|
#cfg(target="native")
let x509_tag_oid : Int = 0x06

///|
#cfg(target="native")
let x509_tag_bit_string : Int = 0x03

///|
#cfg(target="native")
let x509_tag_octet_string : Int = 0x04

///|
#cfg(target="native")
let x509_tag_ia5_string : Int = 0x16

///|
#cfg(target="native")
let x509_tag_utf8_string : Int = 0x0c

///|
#cfg(target="native")
let x509_tag_printable_string : Int = 0x13

///|
#cfg(target="native")
let x509_tag_context_0 : Int = 0xa0

///|
#cfg(target="native")
let x509_tag_context_3 : Int = 0xa3

///|
#cfg(target="native")
let x509_tag_dns_name : Int = 0x82

///|
#cfg(target="native")
let x509_oid_common_name : String = "2.5.4.3"

///|
#cfg(target="native")
let x509_oid_subject_alt_name : String = "2.5.29.17"

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct X509DerElement {
  tag : Int
  header_start : Int
  content_start : Int
  content_end : Int
  end : Int
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct X509CertificateInfo {
  tbs_certificate : Bytes
  signature_algorithm : String
  signature : Bytes
  public_key_algorithm : String
  public_key : Bytes
  dns_names : Array[String]
  common_names : Array[String]
}

///|
#cfg(target="native")
fn x509_der_read_len(data : Bytes, offset : Int) -> (Int, Int) raise {
  guard offset < data.length() else { raise X509DerTruncated }
  let first = data[offset].to_int()
  if first < 0x80 {
    (first, offset + 1)
  } else {
    let len_len = first & 0x7f
    guard len_len > 0 && len_len <= 4 else { raise X509DerUnsupported }
    guard offset + 1 + len_len <= data.length() else { raise X509DerTruncated }
    let mut len = 0
    for i in 0..<len_len {
      len = (len << 8) | data[offset + 1 + i].to_int()
    }
    (len, offset + 1 + len_len)
  }
}

///|
#cfg(target="native")
fn x509_der_read_element(data : Bytes, offset : Int) -> X509DerElement raise {
  guard offset + 2 <= data.length() else { raise X509DerTruncated }
  let tag = data[offset].to_int()
  let (len, content_start) = x509_der_read_len(data, offset + 1)
  let content_end = content_start + len
  guard content_end <= data.length() else { raise X509DerTruncated }
  { tag, header_start: offset, content_start, content_end, end: content_end }
}

///|
#cfg(target="native")
fn x509_der_expect_tag(element : X509DerElement, tag : Int) -> Unit raise {
  guard element.tag == tag else { raise X509DerUnexpectedTag }
}

///|
#cfg(target="native")
fn x509_der_bytes(data : Bytes, element : X509DerElement) -> Bytes {
  tls13_copy_slice(data, element.header_start, element.end)
}

///|
#cfg(target="native")
fn x509_der_content(data : Bytes, element : X509DerElement) -> Bytes {
  tls13_copy_slice(data, element.content_start, element.content_end)
}

///|
#cfg(target="native")
fn x509_der_children(
  data : Bytes,
  element : X509DerElement,
) -> Array[X509DerElement] raise {
  let children = []
  let mut offset = element.content_start
  while offset < element.content_end {
    let child = x509_der_read_element(data, offset)
    guard child.end <= element.content_end else { raise X509DerTruncated }
    children.push(child)
    offset = child.end
  }
  children
}

///|
#cfg(target="native")
fn x509_der_oid(data : Bytes, element : X509DerElement) -> String raise {
  x509_der_expect_tag(element, x509_tag_oid)
  guard element.content_start < element.content_end else {
    raise X509DerTruncated
  }
  let first = data[element.content_start].to_int()
  let out = StringBuilder::new()
  out.write_string("\{first / 40}")
  out.write_string(".")
  out.write_string("\{first % 40}")
  let mut value = 0
  for i in (element.content_start + 1)..<element.content_end {
    let b = data[i].to_int()
    value = (value << 7) | (b & 0x7f)
    if (b & 0x80) == 0 {
      out.write_string(".")
      out.write_string("\{value}")
      value = 0
    }
  }
  guard value == 0 else { raise X509DerTruncated }
  out.to_string()
}

///|
#cfg(target="native")
fn x509_der_bit_string(data : Bytes, element : X509DerElement) -> Bytes raise {
  x509_der_expect_tag(element, x509_tag_bit_string)
  guard element.content_start < element.content_end else {
    raise X509DerTruncated
  }
  guard data[element.content_start].to_int() == 0 else {
    raise X509DerUnsupported
  }
  tls13_copy_slice(data, element.content_start + 1, element.content_end)
}

///|
#cfg(target="native")
fn x509_der_string(data : Bytes, element : X509DerElement) -> String raise {
  guard element.tag == x509_tag_utf8_string ||
    element.tag == x509_tag_printable_string ||
    element.tag == x509_tag_ia5_string else {
    raise X509DerUnexpectedTag
  }
  @utf8.decode_lossy(data[element.content_start:element.content_end])
}

///|
#cfg(target="native")
fn x509_parse_algorithm_identifier(
  data : Bytes,
  element : X509DerElement,
) -> String raise {
  x509_der_expect_tag(element, x509_tag_sequence)
  let children = x509_der_children(data, element)
  guard children.length() >= 1 else { raise X509DerMissingField }
  x509_der_oid(data, children[0])
}

///|
#cfg(target="native")
fn x509_parse_common_names(
  data : Bytes,
  name_element : X509DerElement,
) -> Array[String] raise {
  x509_der_expect_tag(name_element, x509_tag_sequence)
  let names = []
  for rdn in x509_der_children(data, name_element) {
    if rdn.tag == x509_tag_set {
      for attr in x509_der_children(data, rdn) {
        if attr.tag == x509_tag_sequence {
          let children = x509_der_children(data, attr)
          if children.length() >= 2 &&
            x509_der_oid(data, children[0]) == x509_oid_common_name {
            names.push(x509_der_string(data, children[1]))
          }
        }
      }
    }
  }
  names
}

///|
#cfg(target="native")
fn x509_parse_subject_alt_names_from_value(
  value : Bytes,
) -> Array[String] raise {
  let root = x509_der_read_element(value, 0)
  x509_der_expect_tag(root, x509_tag_sequence)
  guard root.end == value.length() else { raise X509DerTruncated }
  let names = []
  let mut offset = root.content_start
  while offset < root.content_end {
    let name = x509_der_read_element(value, offset)
    guard name.end <= root.content_end else { raise X509DerTruncated }
    if name.tag == x509_tag_dns_name {
      names.push(@utf8.decode_lossy(value[name.content_start:name.content_end]))
    }
    offset = name.end
  }
  names
}

///|
#cfg(target="native")
fn x509_parse_extensions(
  data : Bytes,
  extensions_element : X509DerElement,
) -> Array[String] raise {
  x509_der_expect_tag(extensions_element, x509_tag_context_3)
  let wrapped = x509_der_read_element(data, extensions_element.content_start)
  x509_der_expect_tag(wrapped, x509_tag_sequence)
  let dns_names = []
  for extension in x509_der_children(data, wrapped) {
    if extension.tag == x509_tag_sequence {
      let fields = x509_der_children(data, extension)
      guard fields.length() >= 2 else { raise X509DerMissingField }
      if x509_der_oid(data, fields[0]) == x509_oid_subject_alt_name {
        let value_index = if fields[1].tag == x509_tag_octet_string {
          1
        } else {
          2
        }
        guard value_index < fields.length() else { raise X509DerMissingField }
        x509_der_expect_tag(fields[value_index], x509_tag_octet_string)
        let parsed_names = x509_parse_subject_alt_names_from_value(
          x509_der_content(data, fields[value_index]),
        )
        for name in parsed_names {
          dns_names.push(name)
        }
      }
    }
  }
  dns_names
}

///|
#cfg(target="native")
fn x509_parse_subject_public_key_info(
  data : Bytes,
  spki : X509DerElement,
) -> (String, Bytes) raise {
  x509_der_expect_tag(spki, x509_tag_sequence)
  let fields = x509_der_children(data, spki)
  guard fields.length() >= 2 else { raise X509DerMissingField }
  (
    x509_parse_algorithm_identifier(data, fields[0]),
    x509_der_bit_string(data, fields[1]),
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn x509_parse_certificate(data : Bytes) -> X509CertificateInfo raise {
  let cert = x509_der_read_element(data, 0)
  x509_der_expect_tag(cert, x509_tag_sequence)
  guard cert.end == data.length() else { raise X509DerTruncated }
  let cert_fields = x509_der_children(data, cert)
  guard cert_fields.length() >= 3 else { raise X509DerMissingField }
  let tbs = cert_fields[0]
  x509_der_expect_tag(tbs, x509_tag_sequence)
  let tbs_fields = x509_der_children(data, tbs)
  let first_tbs_field = if tbs_fields.length() > 0 {
    tbs_fields[0].tag
  } else {
    raise X509DerMissingField
  }
  let base = if first_tbs_field == x509_tag_context_0 { 1 } else { 0 }
  guard base + 5 < tbs_fields.length() else { raise X509DerMissingField }
  let (public_key_algorithm, public_key) = x509_parse_subject_public_key_info(
    data,
    tbs_fields[base + 5],
  )
  let common_names = x509_parse_common_names(data, tbs_fields[base + 4])
  let dns_names = []
  for i in (base + 6)..<tbs_fields.length() {
    if tbs_fields[i].tag == x509_tag_context_3 {
      let parsed = x509_parse_extensions(data, tbs_fields[i])
      for name in parsed {
        dns_names.push(name)
      }
    }
  }
  {
    tbs_certificate: x509_der_bytes(data, tbs),
    signature_algorithm: x509_parse_algorithm_identifier(data, cert_fields[1]),
    signature: x509_der_bit_string(data, cert_fields[2]),
    public_key_algorithm,
    public_key,
    dns_names,
    common_names,
  }
}
