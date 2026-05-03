
///|
#cfg(not(target="native"))
let _ignore_unused_import : Unit = {
  ignore(@async.sleep)
  ignore(@utf8.encode(""))
}
