///|
async test {
  let res = @mio.get("https://jsonplaceholder.typicode.com/todos/1")
  let json = res.json()
  json_inspect(json, content={
    "userId": 1,
    "id": 1,
    "title": "delectus aut autem",
    "completed": false,
  })
}
