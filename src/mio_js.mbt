///|
/// `suspend` 会中断当前协程的运行。
/// `suspend` 会接受一个回调函数，并让这个回调函数来操作中断的协程
async fn[T, E : Error] suspend(
  // `f` 是负责操作中断的协程的回调函数
  f : (
    // `f` 的第一个参数用于继续运行被中断的协程
    (T) -> Unit,
    // `f` 的第二个参数用于取消被中断的协程。
    // 取消会被表示为在中断处抛出错误
    (E) -> Unit,
  ) -> Unit,
) -> T raise E = "%async.suspend"

///|
async fn request_internal_ffi(
  args : String,
) -> (String, String, Bytes) raise NetworkError {
  suspend(fn(resume_ok, resume_err) {
    request_internal(
      args,
      fn(info, headers, data) {
        resume_ok((info, headers, Bytes::from_array(data)))
      },
      resume_err,
    )
  }) catch {
    _ => raise NetworkError
  }
}

///|
async fn request_stream_internal_ffi(
  args : String,
  on_chunk : (String) -> Unit,
) -> String raise NetworkError {
  suspend(fn(resume_ok, resume_err) {
    request_stream_internal(args, on_chunk, resume_ok, resume_err)
  }) catch {
    _ => raise NetworkError
  }
}

///|
extern "js" fn request_internal(
  args : String,
  resume_ok : (String, String, Array[Byte]) -> Unit,
  resume_err : (Error) -> Unit,
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
  #|    const responseInfo = JSON.stringify({
  #|      "status": res.status,
  #|      "statusText": res.statusText,
  #|      "ok": res.ok
  #|    });
  #|    const headersJson = JSON.stringify(headersObj);
  #|    const dataArray = Array.from(new Uint8Array(buffer));
  #|    resume_ok(responseInfo, headersJson, dataArray);
  #|  } catch (error) {
  #|    resume_err(error)
  #|  }
  #|}

///|
extern "js" fn request_stream_internal(
  args : String,
  on_chunk : (String) -> Unit,
  resume_ok : (String) -> Unit,
  resume_err : (Error) -> Unit,
) -> Unit =
  #|async function(args, on_chunk, resume_ok, resume_err) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options);
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    
  #|    if (res.body && res.body.getReader) {
  #|      const reader = res.body.getReader();
  #|      const decoder = new TextDecoder();
  #|      let buffer = '';
  #|      
  #|      try {
  #|        while (true) {
  #|          const { done, value } = await reader.read();
  #|          if (done) break;
  #|          
  #|          buffer += decoder.decode(value, { stream: true });
  #|          
  #|          // Process complete lines
  #|          let lines = buffer.split('\n');
  #|          buffer = lines.pop() || ''; // Keep incomplete line in buffer
  #|          
  #|          for (const line of lines) {
  #|            if (line.trim()) {
  #|              on_chunk(line + '\n');
  #|            }
  #|          }
  #|        }
  #|        
  #|        // Process any remaining buffer
  #|        if (buffer.trim()) {
  #|          on_chunk(buffer);
  #|        }
  #|        
  #|        resume_ok(
  #|          JSON.stringify({
  #|            "headers": headersObj,
  #|            "status": res.status,
  #|            "statusText": res.statusText,
  #|            "ok": res.ok,
  #|            "data": "stream_completed"
  #|          })
  #|        );
  #|      } catch (streamError) {
  #|        resume_err(streamError);
  #|      }
  #|    } else {
  #|      // Fallback to regular text response
  #|      const text = await res.text();
  #|      on_chunk(text);
  #|      resume_ok(
  #|        JSON.stringify({
  #|          "headers": headersObj,
  #|          "status": res.status,
  #|          "statusText": res.statusText,
  #|          "ok": res.ok,
  #|          "data": text
  #|        })
  #|      );
  #|    }
  #|  } catch (error) {
  #|    resume_err(error);
  #|  }
  #|}
