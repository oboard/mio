# oboard/mio

A powerful HTTP networking package for MoonBit.

## Features

- HTTP GET/POST requests
- JSON response parsing
- File downloads
- Async operations with `@mio.run`

## Usage Examples

### HTTP GET Request
```moonbit
@mio.run(fn() {
  if @mio.get?("https://api.github.com") is Ok(a) {
    println(a.unwrap_json())
  }
})
```

### HTTP POST Request
```moonbit
@mio.run(fn() {
  if @mio.post?("/test", data={ "id": 12, "name": "dio" }) is Ok(a) {
    println(a.unwrap_json())
  }
})
```

### Download File
```moonbit
@mio.run(fn() {
  if @mio.download?("https://api.github.com", save_path="api.json") is Ok(_) {
    println("Downloaded")
  }
})
