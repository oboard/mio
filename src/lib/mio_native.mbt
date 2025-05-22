
///|
extern "js" fn fetch_internal(args : String) -> String!Async =
  #|async function(args, callback) {
  #|  const [url, options] = JSON.parse(args);
  #|  try {
  #|    const res = await fetch(url, options)
  #|    const data = await res.text()
  #|    const headersObj = {};
  #|    res.headers.forEach((value, name) => {
  #|      headersObj[name] = value;
  #|    });
  #|    callback(JSON.stringify({
  #|      "headers": headersObj,
  #|      "status": res.status,
  #|      "statusText": res.statusText,
  #|      "data": data
  #|    }))
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }
