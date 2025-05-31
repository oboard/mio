# oboard/mio

A powerful HTTP networking package for MoonBit.

## Features

- HTTP GET/POST requests
- JSON response parsing
- File downloads
- Async operations with `@mio.run`
- Support for both native and JavaScript backends
  - Native backend uses libcurl for HTTP requests
  - JavaScript backend uses the Fetch API

## Backend Support

### Native Backend
- Uses libcurl for HTTP requests
- Supports all HTTP methods (GET, POST, PUT, DELETE, etc.)
- Full file download capabilities
- JSON parsing and handling

### JavaScript Backend
- Uses the Fetch API
- Compatible with browser and Node.js environments
- Supports all standard HTTP features
- Seamless integration with web applications

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
```