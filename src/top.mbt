///|
fn run_async(f : () -> Unit!Async) -> Unit = "%async.run"

///|
fn main {
  run_async(fn() {
    guard @mio.fetch?("https://api.github.com") is Ok(a) else {
      println("Failed to fetch")
      return
    }
    println(@json.parse?(a.data).or(""))
  })
}
