///|

///|
fn main {
  // get
  @mio.run(fn() {
    if @mio.get?("https://echo.apifox.com/anything") is Ok(a) {
      println(a.unwrap_json())
    }
  })
  // post
  // @mio.run(fn() {
  //   if @mio.post?("https://echo.apifox.com/anything", data={ "id": 12, "name": "mio" }) is Ok(a) {
  //     println(a.text())
  //   }
  // })
  // download
  // @mio.run(fn() {
  //   if @mio.download?("https://echo.apifox.com/anything", save_path="api.json") is Ok(_) {
  //     println("Downloaded")
  //   }
  // })
}
