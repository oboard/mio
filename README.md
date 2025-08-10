# oboard/mio

A powerful and modern HTTP networking library for MoonBit with multi-backend support.

[![Version](https://img.shields.io/badge/version-0.3.0-blue.svg)](https://github.com/oboard/mio)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

## Features

- 🚀 **Async/Await Support**: Built-in async operations with `@mio.run`
- 🌐 **Complete HTTP Methods**: GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD, CONNECT, TRACE
- 📄 **JSON Handling**: Seamless JSON parsing and response handling
- 📁 **File Downloads**: Built-in file download capabilities with custom save paths
- 🌊 **Stream Processing**: Real-time data streaming with callback support
- 🎯 **Multi-Backend**: Support for Native (libcurl), JavaScript (Fetch API), and WASM
- ⚡ **Type Safety**: Full MoonBit type system support with error handling
- 🔧 **Flexible Options**: Headers, credentials, modes, and request customization

## Backend Support

### Native Backend (`native`, `llvm`)
- **HTTP Engine**: libcurl for robust HTTP requests
- **Features**: All HTTP methods, file downloads, full header support
- **Dependencies**: Requires libcurl system library
- **Performance**: Optimized for server-side and native applications

### JavaScript Backend (`js`)
- **HTTP Engine**: Fetch API
- **Features**: Browser and Node.js compatibility
- **Dependencies**: No external dependencies
- **Performance**: Optimized for web applications and frontend development

### WebAssembly Backend (`wasm`, `wasm-gc`)
- **HTTP Engine**: WASM-compatible implementation
- **Features**: Cross-platform WebAssembly support
- **Dependencies**: WASM runtime environment
- **Performance**: Optimized for WASM applications

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "oboard/mio": "0.3.0"
  }
}
```

## Quick Start

### Basic GET Request

```moonbit
@mio.run(fn() {
  match (try? @mio.get("https://api.github.com")) {
    Ok(response) => {
      println("Status: " + response.statusCode.to_string())
      println("Response: " + response.text())
    }
    Err(e) => println("Error: " + e.to_string())
  }
})
```

### POST Request with JSON Data

```moonbit
@mio.run(fn() {
  match (try? @mio.post("https://httpbin.org/post", 
    data={ 
      "name": "MoonBit", 
      "version": "0.3.0",
      "features": ["async", "http", "json"]
    })) {
    Ok(response) => {
      println("Posted successfully!")
      println(response.unwrap_json())
    }
    Err(e) => println("Failed: " + e.to_string())
  }
})
```

### Custom Headers and Options

```moonbit
@mio.run(fn() {
  let headers = {
    "Authorization": "Bearer your-token",
    "User-Agent": "MoonBit-App/1.0",
    "Accept": "application/json"
  }
  
  match (try? @mio.get("https://api.example.com/data", 
    headers=headers,
    credentials=SameOrigin,
    mode=CORS)) {
    Ok(response) => {
      if response.statusCode == 200 {
        let data = response.json()
        // Process your data
      }
    }
    Err(e) => println("Request failed: " + e.to_string())
  }
})
```

### File Download

```moonbit
@mio.run(fn() {
  // Download with custom filename
  match (try? @mio.download("https://api.github.com/repos/moonbitlang/core",
    save_path="github_repo.json")) {
    Ok(_) => println("File downloaded successfully!")
    Err(e) => println("Download failed: " + e.to_string())
  }
  
  // Download with dynamic filename based on headers
  match (try? @mio.download("https://example.com/file.zip",
    save_path_fn=fn(headers) {
      match headers.get("content-disposition") {
        Some(disposition) => extract_filename(disposition)
        None => "downloaded_file.zip"
      }
    })) {
    Ok(_) => println("File downloaded with dynamic name!")
    Err(e) => println("Download failed: " + e.to_string())
  }
})
```

### Stream Requests

```moonbit
@mio.run(fn() {
  // Stream processing with real-time data handling
  let chunks = []
  
  match (try? @mio.get_stream("https://api.example.com/stream",
    fn(chunk) {
      println("Received chunk: " + chunk)
      chunks.push(chunk)
      // Process each chunk as it arrives
    })) {
    Ok(response) => {
      println("Stream completed with status: " + response.statusCode.to_string())
      println("Total chunks received: " + chunks.length().to_string())
    }
    Err(e) => println("Stream failed: " + e.to_string())
  }
})
```

**Note**: Stream functionality is currently under development for native backend due to callback compatibility issues between MoonBit and C function pointers. It works properly on JavaScript and WASM backends.

## API Reference

### HTTP Methods

All HTTP methods support the same optional parameters:

- `headers?: Map[String, String]` - Custom HTTP headers
- `credentials?: FetchCredentials` - Request credentials (Omit, SameOrigin, Include)
- `mode?: FetchMode` - Request mode (CORS, NoCORS, SameOrigin, Navigate)

```moonbit
// GET request
(try? @mio.get(url, headers?, credentials?, mode?))

// POST request with body or JSON data
(try? @mio.post(url, body?, data?, headers?, credentials?, mode?))

// Other HTTP methods
(try? @mio.put(url, body?, headers?, credentials?, mode?))
(try? @mio.delete(url, body?, headers?, credentials?, mode?))
(try? @mio.patch(url, body?, headers?, credentials?, mode?))
(try? @mio.options(url, body?, headers?, credentials?, mode?))
(try? @mio.head(url, body?, headers?, credentials?, mode?))
(try? @mio.connect(url, body?, headers?, credentials?, mode?))
(try? @mio.trace(url, body?, headers?, credentials?, mode?))

// Stream request with callback for real-time data processing
(try? @mio.get_stream(url, callback, headers?, credentials?, mode?))
```

### Response Handling

```moonbit
// HttpResponse methods
response.text()          // Get response as string
response.json()          // Parse JSON (may raise ParseError)
response.unwrap_json()   // Safe JSON parsing (returns Json::null() on error)
response.statusCode      // HTTP status code
response.headers         // Response headers as Map[String, String]
response.data           // Raw response data as Bytes
```

### Error Handling

The library defines three main error types:

- `IOError` - File system and I/O related errors
- `NetworkError` - Network and HTTP request errors  
- `ExecError` - Execution and runtime errors

## Advanced Usage

### Custom Request with Full Control

```moonbit
@mio.run(fn() {
  match (try? @mio.request("https://api.example.com/upload",
    http_method=POST,
    body="custom request body",
    headers={
      "Content-Type": "text/plain",
      "X-Custom-Header": "value"
    },
    credentials=Include,
    mode=CORS)) {
    Ok(response) => {
      // Handle response
    }
    Err(NetworkError) => {
      // Handle network errors
    }
  }
})
```

### Buffer Requests for Binary Data

```moonbit
@mio.run(fn() {
  match (try? @mio.request_buffer("https://example.com/image.png")) {
    Ok(response) => {
      // response.data contains raw bytes
      @fs.write_bytes_to_file("image.png", response.data)
    }
    Err(e) => println("Failed to download image")
  }
})
```

## Examples

Check out these real-world projects using mio:

- **[weatherquery](https://github.com/oboard/weatherquery)** - Weather query tool for Chinese locations
  - Fetches real-time weather data from APIs
  - Supports provinces, cities, and districts
  - Cross-platform (native and web)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.