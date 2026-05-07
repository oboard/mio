# mio HTTP Client Benchmarks

This directory contains two benchmark layers:

- MoonBit package benchmarks in `bench_wbtest.mbt`, run by `moon test`.
- Cross-runtime HTTP client benchmarks for `mio`, Node.js, Bun, Go, and Rust
  `hyper`, run by `benchmarks/scripts/run-http-client-bench.mjs`.

The MoonBit package benchmarks follow the `test (b : @bench.T)` form described
in the [MoonBit benchmark guide](https://docs.moonbitlang.cn/language/benchmarks.html).

The cross-runtime benchmark starts one local HTTP/1.1 server, then runs each
client against the same URL with the same request and warmup counts. Every
client performs sequential GET requests and reads the full response body.
The `mio` and `hyper` clients are run in release mode.

## Run

```sh
moon test --target native
node benchmarks/scripts/run-http-client-bench.mjs --requests 10000 --warmup 200
```

The runner skips a runtime if its executable is unavailable. `hyper` requires
Cargo and downloads Rust crates the first time it is run.

Useful options:

```sh
node benchmarks/scripts/run-http-client-bench.mjs \
  --requests 20000 \
  --warmup 500 \
  --port 3200 \
  --payload-bytes 128
```

Each client prints a JSON object with:

- `runtime`
- `requests`
- `warmup`
- `elapsed_ms`
- `requests_per_sec`
- `bytes`
