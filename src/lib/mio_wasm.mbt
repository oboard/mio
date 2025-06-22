///| `suspend` 会中断当前协程的运行。
/// `suspend` 会接受一个回调函数，并让这个回调函数来操作中断的协程
async fn[T, E : Error] suspend(
  // `f` 是负责操作中断的协程的回调函数
  f : (
    // `f` 的第一个参数用于继续运行被中断的协程
    (T) -> Unit,
    // `f` 的第二个参数用于取消被中断的协程。
    // 取消会被表示为在中断处抛出错误
    (E) -> Unit,
  ) -> Unit
) -> T raise E = "%async.suspend"

///|
#external
priv type HttpHandle

///|
priv struct WasiHttpResponse {
  status_code : Int
  headers : Map[String, String]
  body : Bytes
}

///|
fn http_request(
  url : String,
  methodStr : String,
  headers : Map[String, String],
  body : Bytes?
) -> WasiHttpResponse raise NetworkError {
  let headers_str = headers.to_array().to_json().stringify()
  let body_bytes = if body is Some(b) { b } else { Bytes::from_array([]) }
  match wasi_http_request(url, methodStr, headers_str, body_bytes) {
    Ok((status, handle)) => {
      let headers_map = {}
      let headers_buf = Bytes::from_array([])
      if wasi_http_headers_get_all(handle, headers_buf) is Ok(size) {
        if size > 0 {
          let headers_str = @encoding.decode(headers_buf, encoding=UTF8) catch {
            _ => ""
          }
          if (try? @json.parse(headers_str)) is Ok(json) {
            if json is Object(obj) {
              for k, v in obj {
                headers_map.set(k, v.as_string().or(""))
              }
            }
          }
        }
      }
      let body_buf = Bytes::from_array([])
      let body_bytes = if wasi_http_body_read(handle, body_buf) is Ok(size) {
        if size > 0 {
          body_buf
        } else {
          Bytes::from_array([])
        }
      } else {
        Bytes::from_array([])
      }
      let _ = wasi_http_close(handle)
      WasiHttpResponse::{
        status_code: status,
        headers: headers_map,
        body: body_bytes,
      }
    }
    _ => raise NetworkError
  }
}

///|
fn wasi_http_request(
  url : String,
  method : String,
  headers : String,
  body : Bytes
) -> Result[(Int, HttpHandle), NetworkError] = "wasm" "req"

///|
fn wasi_http_close(handle : HttpHandle) -> Result[Unit, NetworkError] = "wasm" "close"

///|
fn wasi_http_headers_get_all(
  handle : HttpHandle,
  buf : Bytes
) -> Result[Int, NetworkError] = "wasm" "headers_get_all"

///|
fn wasi_http_body_read(
  handle : HttpHandle,
  buf : Bytes
) -> Result[Int, NetworkError] = "wasm" "body_read"

///|
pub async fn request_buffer_internal_ffi(
  args : String
) -> String raise NetworkError {
  let [url, options] = @json.parse(args).as_array().or([]) catch {
    _ => raise NetworkError
  }
  let url_str = url.as_string().or("")
  match options {
    { "method": String(m), "headers": Object(headers), .. } => {
      let body_bytes = match options {
        { "body": String(s), .. } => Some(s.to_bytes())
        _ => None
      }
      let mHeaders = {}
      for k, v in headers {
        if v.as_string() is Some(s) {
          mHeaders.set(k, s)
        }
      }
      let response = http_request(url_str, m, mHeaders, body_bytes)
      Json::object({
        "headers": response.headers.to_json(),
        "status": response.status_code.to_json(),
        "statusText": "",
        "ok": (response.status_code >= 200 && response.status_code < 300).to_json(),
        "data": response.body.to_array().to_json(),
      }).stringify()
    }
  }
}

///|
pub async fn request_text_internal_ffi(args : String) -> String raise Error {
  let [url, options] = @json.parse(args).as_array().or([]) catch {
    _ => raise NetworkError
  }
  let url_str = url.as_string().or("")
  match options {
    { "method": String(m), "headers": Object(headers), .. } => {
      let body_bytes = match options {
        { "body": String(s), .. } => Some(s.to_bytes())
        _ => None
      }
      let mHeaders = {}
      for k, v in headers {
        if v.as_string() is Some(s) {
          mHeaders.set(k, s)
        }
      }
      let response = http_request(url_str, m, mHeaders, body_bytes)
      Json::object({
        "headers": response.headers.to_json(),
        "status": response.status_code.to_json(),
        "statusText": "",
        "ok": (response.status_code >= 200 && response.status_code < 300).to_json(),
        "data": @encoding.decode(response.body, encoding=UTF8).to_json(),
      }).stringify()
    }
  }
}
