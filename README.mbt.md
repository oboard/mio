# oboard/mio

A powerful and modern HTTP networking library for MoonBit with multi-backend support.

[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](https://github.com/oboard/mio)
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

```moonbit nocheck
let response = @mio.get("https://api.github.com") catch {
    Err(e) => println("Error: " + e.to_string())
}
println("Response: " + response.text())
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
