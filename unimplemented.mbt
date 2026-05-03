///|
/// This package currently does not support JavaScript backend
#cfg(not(target="native"))
#coverage.skip
pub let unimplemented : Unit = {
  ignore(@io.pipe)
  ignore(@socket.unimplemented)
  ignore(@tls.unimplemented)
  ignore(@gzip.Decoder::new)
}

///|
#cfg(not(target="js"))
#coverage.skip
#warnings("-alert_unimplemented")
let _unused : Unit = ignore(@js_async.AbortController::new)
