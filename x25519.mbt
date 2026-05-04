///|
#cfg(target="native")
priv suberror X25519Error {
  X25519BadScalarLength
  X25519BadPointLength
} derive(Debug, ToJson)

///|
#cfg(target="native")
let x25519_121665 : FixedArray[Int64] = {
  let out = FixedArray::make(16, 0L)
  out[0] = 0xdb41L
  out[1] = 1L
  out
}

///|
#cfg(target="native")
fn x25519_gf(
  init? : FixedArray[Int64] = FixedArray::make(16, 0L),
) -> FixedArray[Int64] {
  let out = FixedArray::make(16, 0L)
  for i in 0..<16 {
    out[i] = init[i]
  }
  out
}

///|
#cfg(target="native")
fn x25519_carry(o : FixedArray[Int64]) -> Unit {
  let mut carry = 1L
  for i in 0..<16 {
    let value = o[i] + carry + 65535L
    carry = value >> 16
    o[i] = value - carry * 65536L
  }
  o[0] += 38L * (carry - 1L)
}

///|
#cfg(target="native")
fn x25519_select(
  p : FixedArray[Int64],
  q : FixedArray[Int64],
  bit : Int64,
) -> Unit {
  let mask = (bit - 1L).lnot()
  for i in 0..<16 {
    let t = mask & (p[i] ^ q[i])
    p[i] = p[i] ^ t
    q[i] = q[i] ^ t
  }
}

///|
#cfg(target="native")
fn x25519_add(
  o : FixedArray[Int64],
  a : FixedArray[Int64],
  b : FixedArray[Int64],
) -> Unit {
  for i in 0..<16 {
    o[i] = a[i] + b[i]
  }
}

///|
#cfg(target="native")
fn x25519_sub(
  o : FixedArray[Int64],
  a : FixedArray[Int64],
  b : FixedArray[Int64],
) -> Unit {
  for i in 0..<16 {
    o[i] = a[i] - b[i]
  }
}

///|
#cfg(target="native")
fn x25519_mul(
  o : FixedArray[Int64],
  a : FixedArray[Int64],
  b : FixedArray[Int64],
) -> Unit {
  let t = FixedArray::make(31, 0L)
  for i in 0..<16 {
    for j in 0..<16 {
      t[i + j] += a[i] * b[j]
    }
  }
  for i in 0..<15 {
    t[i] += 38L * t[i + 16]
  }
  for i in 0..<16 {
    o[i] = t[i]
  }
  x25519_carry(o)
  x25519_carry(o)
}

///|
#cfg(target="native")
fn x25519_square(o : FixedArray[Int64], a : FixedArray[Int64]) -> Unit {
  x25519_mul(o, a, a)
}

///|
#cfg(target="native")
fn x25519_inverse(o : FixedArray[Int64], i : FixedArray[Int64]) -> Unit {
  let c = x25519_gf(init=i)
  for a = 253; a >= 0; a = a - 1 {
    x25519_square(c, c)
    if a != 2 && a != 4 {
      x25519_mul(c, c, i)
    }
  }
  for a in 0..<16 {
    o[a] = c[a]
  }
}

///|
#cfg(target="native")
fn x25519_pack(n : FixedArray[Int64]) -> Bytes {
  let t = x25519_gf(init=n)
  let m = FixedArray::make(16, 0L)
  for _ in 0..<3 {
    x25519_carry(t)
  }
  for _ in 0..<2 {
    m[0] = t[0] - 0xffedL
    for i in 1..<15 {
      m[i] = t[i] - 0xffffL - ((m[i - 1] >> 16) & 1L)
      m[i - 1] = m[i - 1] & 0xffffL
    }
    m[15] = t[15] - 0x7fffL - ((m[14] >> 16) & 1L)
    let b = (m[15] >> 16) & 1L
    m[14] = m[14] & 0xffffL
    x25519_select(t, m, 1L - b)
  }
  let out = @buffer.new()
  for i in 0..<16 {
    out.write_byte((t[i] & 0xffL).to_byte())
    out.write_byte(((t[i] >> 8) & 0xffL).to_byte())
  }
  out.contents()
}

///|
#cfg(target="native")
fn x25519_unpack(point : Bytes) -> FixedArray[Int64] raise {
  guard point.length() == 32 else { raise X25519BadPointLength }
  let out = FixedArray::make(16, 0L)
  for i in 0..<16 {
    out[i] = point[2 * i].to_int64() + (point[2 * i + 1].to_int64() << 8)
  }
  out[15] = out[15] & 0x7fffL
  out
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn x25519(scalar : Bytes, point : Bytes) -> Bytes raise {
  guard scalar.length() == 32 else { raise X25519BadScalarLength }
  guard point.length() == 32 else { raise X25519BadPointLength }
  let z = FixedArray::make(32, b'\x00')
  for i in 0..<32 {
    z[i] = scalar[i]
  }
  z[0] = z[0] & b'\xf8'
  z[31] = (z[31] & b'\x7f') | b'\x40'
  let x = x25519_unpack(point)
  let a = x25519_gf()
  let b = x25519_gf()
  let c = x25519_gf()
  let d = x25519_gf()
  let e = x25519_gf()
  let f = x25519_gf()
  for i in 0..<16 {
    b[i] = x[i]
  }
  a[0] = 1L
  d[0] = 1L
  for pos = 254; pos >= 0; pos = pos - 1 {
    let bit = ((z[pos >> 3].to_int() >> (pos & 7)) & 1).to_int64()
    x25519_select(a, b, bit)
    x25519_select(c, d, bit)
    x25519_add(e, a, c)
    x25519_sub(a, a, c)
    x25519_add(c, b, d)
    x25519_sub(b, b, d)
    x25519_square(d, e)
    x25519_square(f, a)
    x25519_mul(a, c, a)
    x25519_mul(c, b, e)
    x25519_add(e, a, c)
    x25519_sub(a, a, c)
    x25519_square(b, a)
    x25519_sub(c, d, f)
    x25519_mul(a, c, x25519_121665)
    x25519_add(a, a, d)
    x25519_mul(c, c, a)
    x25519_mul(a, d, f)
    x25519_mul(d, b, x)
    x25519_square(b, e)
    x25519_select(a, b, bit)
    x25519_select(c, d, bit)
  }
  x25519_inverse(c, c)
  x25519_mul(a, a, c)
  x25519_pack(a)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn x25519_base(scalar : Bytes) -> Bytes raise {
  let base = FixedArray::make(32, b'\x00')
  base[0] = b'\x09'
  x25519(scalar, base.unsafe_reinterpret_as_bytes())
}
