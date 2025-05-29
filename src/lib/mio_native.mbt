///|
extern "c" fn request_buffer_internal(args : @native.Ptr[Byte], callback : @native.Ptr[Byte]) -> @native.Ptr[Byte] = "request_buffer_internal"

///|
extern "c" fn request_text_internal(args : @native.Ptr[Byte], callback : @native.Ptr[Byte]) -> @native.Ptr[Byte] = "request_text_internal"

///|
pub async fn request_buffer_internal_ffi(args : String) -> String!NetworkError {
  let (cstr, _) = @native.CStr::from_bytes(args.to_bytes())
  let result_ptr = request_buffer_internal(@native.unsafe_coerce(cstr.reinterpret_as_const_byte_ptr()), @native.unsafe_coerce(cstr.reinterpret_as_const_byte_ptr()))
  if result_ptr.is_null() {
    raise NetworkError
  }
  let result = @native.CStr::unsafe_from_byte_ptr(result_ptr).to_bytes().to_string()
  @native.free(result_ptr)
  result
}

///|
pub async fn request_text_internal_ffi(args : String) -> String!NetworkError {
  let (cstr, _) = @native.CStr::from_bytes(args.to_bytes())
  let result_ptr = request_text_internal(@native.unsafe_coerce(cstr.reinterpret_as_const_byte_ptr()), @native.unsafe_coerce(cstr.reinterpret_as_const_byte_ptr()))
  if result_ptr.is_null() {
    raise NetworkError
  }
  let result = @native.CStr::unsafe_from_byte_ptr(result_ptr).to_bytes().to_string()
  @native.free(result_ptr)
  result
}