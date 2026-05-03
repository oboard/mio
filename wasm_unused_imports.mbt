///|
let _ignore_wasm_unused_imports : Unit = {
  let empty = b""
  ignore(@brotli.decompress(empty) catch { _ => empty })
  ignore(@flate.decompress(empty) catch { _ => empty })
  ignore(@zstd.decompress(empty) catch { _ => empty })
}
