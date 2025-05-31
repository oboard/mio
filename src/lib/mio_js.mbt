///|
async fn request_buffer_internal_ffi(args : String) -> String {
  request_buffer_internal(args)
}

///|
async fn request_text_internal_ffi(args : String) -> String {
  request_text_internal(args)
}

///|
extern "js" fn request_buffer_internal(args : String) -> String!Async =
  #|async function(args, callback) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options)
  #|    const buffer = await res.arrayBuffer()
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    callback(
  #|      JSON.stringify({
  #|        "headers": headersObj,
  #|        "status": res.status,
  #|        "statusText": res.statusText,
  #|        "ok": res.ok,
  #|        "data": new Uint8Array(buffer)
  #|      }),
  #|     )
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #|}

///|
extern "js" fn request_text_internal(args : String) -> String!Async =
  #|async function(args, callback) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options)
  #|    const text = await res.text()
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    callback(
  #|      JSON.stringify({
  #|        "headers": headersObj,
  #|        "status": res.status,
  #|        "statusText": res.statusText,
  #|        "ok": res.ok,
  #|        "data": text
  #|      }),
  #|     )
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #|}
