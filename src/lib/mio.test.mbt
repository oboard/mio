///|
test "get" {
  run(fn() {
    if (try? get("https://echo.apifox.com/anything")) is Ok(a) {
      println(a.unwrap_json())
    }
  })
}

///|
test "post" {
  run(fn() {
    if (try? post("https://echo.apifox.com/anything", data={
        "id": 12,
        "name": "mio",
      }))
      is Ok(a) {
      println(a.text())
    }
  })
}

///|
test "download" {
  run(fn() {
    if (try? download("https://api.github.com", save_path="api.json")) is Ok(_) {
      println("Downloaded")
    }
  })
}

///|
test "stream" {
  run(fn() {
    let chunks = []
    if (try? get_stream("https://httpbin.org/stream/3", chunk => {
        println("receive: " + chunk)
        chunks.push(chunk)
      }))
      is Ok(response) {
      if response.statusCode != 200 {
        abort("Expected status 200, got " + response.statusCode.to_string())
      }
      if chunks.length() == 0 {
        abort("Expected to receive chunks")
      }
      println("receive " + chunks.length().to_string() + " chunks")
    }
  })
}
