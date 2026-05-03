///|
async test {
  let res = @mio.get("https://jsonplaceholder.typicode.com/todos/1")
  let json = res.json()
  println(json)
}
