///|
fn run_async(f : () -> Unit!Async) -> Unit = "%async.run"

///|
fn main {
  run_async(fn() {
    if @mio.get?("https://api.github.com") is Ok(a) {
      println(a.json?().or(""))
    }
  })
}
