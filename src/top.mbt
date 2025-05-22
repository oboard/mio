///|

///|
fn main {
  // get
  @mio.run(fn() {
    if @mio.get?("https://api.github.com") is Ok(a) {
      println(a.unwrap_json())
    }
  })
  // post
  @mio.run(fn() {
    if @mio.post?("/test", data={ "id": 12, "name": "dio" }) is Ok(a) {
      println(a.unwrap_json())
    }
  })
  // download
  @mio.run(fn() {
    if @mio.download?("https://api.github.com", save_path="api.json") is Ok(_) {
      println("Downloaded")
    }
  })
}
