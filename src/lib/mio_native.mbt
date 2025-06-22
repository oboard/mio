///|
extern "c" fn request_buffer_internal(
  args : @native.Ptr[Byte],
  callback : @native.Ptr[Byte]
) -> @native.Ptr[Byte] = "request_buffer_internal"

///|
extern "c" fn request_text_internal(
  args : @native.Ptr[Byte],
  callback : @native.Ptr[Byte]
) -> @native.Ptr[Byte] = "request_text_internal"

///|
extern "c" fn utf16le_to_utf8(
  utf16le : @native.Ptr[Byte],
  len : Int
) -> @native.Ptr[Byte] = "utf16le_to_utf8"

///|
extern "c" fn utf8_to_utf16le(
  utf8 : @native.Ptr[Byte],
  out_len : @native.Ptr[Int]
) -> @native.Ptr[Byte] = "utf8_to_utf16le"

///|
pub async fn request_buffer_internal_ffi(
  args : String
) -> String raise NetworkError {
  println("[MB DEBUG] request_buffer_internal_ffi - Input args: " + args)

  // 使用 encoding 库将字符串转换为 UTF-8 字节
  let bytes = @encoding.encode(args, encoding=UTF8)
  println(
    "[MB DEBUG] request_buffer_internal_ffi - Bytes length: " +
    bytes.length().to_string(),
  )
  let utf8_ptr = @native.unsafe_coerce(bytes)
  let result_ptr = request_buffer_internal(utf8_ptr, utf8_ptr)
  if result_ptr.is_null() {
    // println("[MB DEBUG] request_buffer_internal_ffi - Request failed")
    raise NetworkError
  }

  // 使用 CStr 转换为字节，然后使用 encoding 库解码为字符串
  let result_bytes = @native.CStr::unsafe_from_byte_ptr(result_ptr).to_bytes()
  // 去除末尾的 null 字符
  match (try? @encoding.decode(result_bytes, encoding=UTF8)) {
    Ok(text) => {
      println("[MB DEBUG] request_buffer_internal_ffi - Response: " + text)
      @native.free(result_ptr)
      text
    }
    _ => {
      println("[MB DEBUG] request_buffer_internal_ffi - Decoding failed")
      @native.free(result_ptr)
      raise NetworkError
    }
  }
}

///|
pub async fn request_text_internal_ffi(
  args : String
) -> String raise NetworkError {
  // 使用 encoding 库将字符串转换为 UTF-8 字节
  let bytes = @encoding.encode(args, encoding=UTF8)
  let utf8_ptr = @native.unsafe_coerce(bytes)
  let result_ptr = request_text_internal(utf8_ptr, utf8_ptr)
  if result_ptr.is_null() {
    // println("[MB DEBUG] request_text_internal_ffi - Request failed")
    raise NetworkError
  }

  // 使用 CStr 转换为字节，然后使用 encoding 库解码为字符串
  let result_bytes = @native.CStr::unsafe_from_byte_ptr(result_ptr).to_bytes()[0:-1] // 去除 \u{00}
  match (try? @encoding.decode(result_bytes, encoding=UTF8)) {
    Ok(text) => {
      @native.free(result_ptr)
      text
    }
    _ => {
      println("[MB DEBUG] request_text_internal_ffi - Decoding failed")
      @native.free(result_ptr)
      raise NetworkError
    }
  }
}
