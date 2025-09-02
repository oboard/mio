///|
#owned(args, callback)
extern "c" fn request_internal(
  args : @native.Ptr[Byte],
  callback : @native.Ptr[Byte],
) -> @native.Ptr[Byte] = "request_internal"

///|
#owned(args, callback)
extern "c" fn request_stream_internal(
  args : @native.Ptr[Byte],
  callback : @native.Ptr[Byte],
) -> @native.Ptr[Byte] = "request_stream_internal"

// 移除不再使用的set_moonbit_callback函数

// 移除全局回调机制，直接使用函数指针

///|
pub async fn request_internal_ffi(
  args : String,
) -> (String, String, Bytes) raise NetworkError {
  println("[MB DEBUG] request_internal_ffi - Input args: " + args)

  // 使用 encoding 库将字符串转换为 UTF-8 字节
  let bytes = @encoding.encode(UTF8, args)
  println(
    "[MB DEBUG] request_internal_ffi - Bytes length: " +
    bytes.length().to_string(),
  )
  let utf8_ptr = @native.unsafe_coerce(bytes)
  let result_ptr = request_internal(utf8_ptr, utf8_ptr)
  if result_ptr.is_null() {
    raise NetworkError
  }

  // 使用 CStr 转换为字节，然后使用 encoding 库解码为字符串
  let result_bytes = @native.CStr::unsafe_from_byte_ptr(result_ptr).to_bytes()[0:-1]
  match (try? @encoding.decoder(UTF8).decode(result_bytes)) {
    Ok(text) => {
      println("[MB DEBUG] request_internal_ffi - Response: " + text)
      @native.free(result_ptr)
      // 解析响应，分离headers和data
      match (try? @json.parse(text)) {
        Ok(
          {
            "response_info": String(info),
            "headers": String(headers),
            "data": String(data_str),
            ..
          }
        ) => {
          // 将字符串数据转换为Bytes，与JS平台保持一致
          let bytes_data = @encoding.encode(UTF8, data_str)
          (info, headers, bytes_data)
        }
        _ => raise NetworkError
      }
    }
    _ => {
      println("[MB DEBUG] request_internal_ffi - Decoding failed")
      @native.free(result_ptr)
      raise NetworkError
    }
  }
}

///|
pub async fn request_stream_internal_ffi(
  args : String,
  on_chunk : (String) -> Unit,
) -> String raise NetworkError {
  raise NetworkError
}
