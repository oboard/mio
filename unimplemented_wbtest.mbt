///|
#cfg(not(target="native"))
fn _ignore_unused_import() -> Unit {
  let _ : (&@io.Reader) -> _ = @gzip.Decoder::new
  ignore(@async.sleep)
  ignore(@fs.unimplemented)
  ignore(@utf8.encode(""))
}
