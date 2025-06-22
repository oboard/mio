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
async fn request_buffer_internal_ffi(
  args : String
) -> String raise NetworkError {
  suspend(fn(resume_ok, resume_err) {
    request_buffer_internal(args, resume_ok, resume_err)
  }) catch {
    _ => raise NetworkError
  }
}

///|
async fn request_text_internal_ffi(args : String) -> String raise NetworkError {
  suspend(fn(resume_ok, resume_err) {
    request_text_internal(args, resume_ok, resume_err)
  }) catch {
    _ => raise NetworkError
  }
}

///|
extern "js" fn request_buffer_internal(
  args : String,
  resume_ok : (String) -> Unit,
  resume_err : (Error) -> Unit
) -> Unit =
  #|async function(args, resume_ok, resume_err) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options)
  #|    const buffer = await res.arrayBuffer()
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    resume_ok(
  #|      JSON.stringify({
  #|        "headers": headersObj,
  #|        "status": res.status,
  #|        "statusText": res.statusText,
  #|        "ok": res.ok,
  #|        "data": new Uint8Array(buffer)
  #|      }),
  #|     )
  #|  } catch (error) {
  #|    resume_err(error)
  #|  }
  #|}

///|
extern "js" fn request_text_internal(
  args : String,
  resume_ok : (String) -> Unit,
  resume_err : (Error) -> Unit
) -> Unit =
  #|async function(args, resume_ok, resume_err) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options)
  #|    const text = await res.text()
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    resume_ok(
  #|      JSON.stringify({
  #|        "headers": headersObj,
  #|        "status": res.status,
  #|        "statusText": res.statusText,
  #|        "ok": res.ok,
  #|        "data": text
  #|      }),
  #|     )
  #|  } catch (error) {
  #|    resume_err(error)
  #|  }
  #|}
