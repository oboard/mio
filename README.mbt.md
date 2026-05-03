# oboard/mio

A powerful and modern HTTP networking library for MoonBit with multi-backend support.

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/oboard/mio)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

## Features

- 🚀 **Async/Await Support**: Built-in async operations with `@mio.run`
- 🌐 **Complete HTTP Methods**: GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD, CONNECT, TRACE
- 📄 **JSON Handling**: Seamless JSON parsing and response handling
- 📁 **File Downloads**: Built-in file download capabilities with custom save paths
- 🌊 **Stream Processing**: Real-time data streaming with callback support
- 📦 **Binary Data Support**: Native handling of binary data with unified `Bytes` interface across all backends
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
    "oboard/mio": "0.4.0"
  }
}
```

## Quick Start

### Basic GET Request

```moonbit
let response = @mio.get("https://api.github.com") catch {
    Err(e) => println("Error: " + e.to_string())
}
println("Status: " + response.status_code.to_string())
println("Response: " + response.text())
```

### POST Request with JSON Data

```moonbit
```

### Custom Headers and Options

```moonbit
let headers = {
"Authorization": "Bearer your-token",
"User-Agent": "MoonBit-App/1.0",
"Accept": "application/json"
}
let response = @mio.get("https://api.example.com/data", 
    headers=headers,
    credentials=SameOrigin,
    mode=CORS
) catch {
    e => println("Request failed: " + e.to_string())
}

if response.statusCode == 200 {
let data = response.json()
// Process your data
}


```

### Stream Requests

```moonbit
  // Stream processing with real-time data handling
let chunks = []
let res = @mio.get_stream("https://api.example.com/stream", (chunk) => {
    println("Received chunk: " + chunk)
    chunks.push(chunk)
    // Process each chunk as it arrives
}) catch {
    e => println("Stream failed: " + e.to_string())
}

println("Stream completed with status: " + res.status_code.to_string())
println("Total chunks received: " + chunks.length().to_string())
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
@mio.get(url, headers?, credentials?, mode?)

// POST request with body or JSON data
@mio.post(url, body?, data?, headers?, credentials?, mode?))

// Other HTTP methods
@mio.put(url, body?, headers?, credentials?, mode?)
@mio.delete(url, body?, headers?, credentials?, mode?)
@mio.patch(url, body?, headers?, credentials?, mode?)
@mio.options(url, body?, headers?, credentials?, mode?)
@mio.head(url, body?, headers?, credentials?, mode?)
@mio.connect(url, body?, headers?, credentials?, mode?)
@mio.trace(url, body?, headers?, credentials?, mode?)

// Stream request with callback for real-time data processing
@mio.get_stream(url, callback, headers?, credentials?, mode?)
```

### Response Handling

```moonbit
// HttpResponse methods
response.text()          // Get response as string
response.json()          // Parse JSON (may raise ParseError)
response.unwrap_json()   // Safe JSON parsing (returns Json::null() on error)
response.status_code      // HTTP status code
response.headers         // Response headers as Map[String, String]
response.data           // Raw response data as Bytes
```

### Error Handling

The library defines three main error types:

- `IOError` - File system and I/O related errors
- `NetworkError` - Network and HTTP request errors  
- `ExecError` - Execution and runtime errors

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
