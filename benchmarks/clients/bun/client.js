const args = parseArgs(Bun.argv.slice(2));
const url = args.url ?? "http://127.0.0.1:3200/payload";
const requests = Number(args.requests ?? 10_000);
const warmup = Number(args.warmup ?? 200);

for (let i = 0; i < warmup; i += 1) {
  await issueRequest(url);
}

let bytes = 0;
const started = performance.now();
for (let i = 0; i < requests; i += 1) {
  bytes += await issueRequest(url);
}
const elapsedMs = performance.now() - started;

console.log(JSON.stringify({
  runtime: "bun",
  requests,
  warmup,
  elapsed_ms: elapsedMs,
  requests_per_sec: requests * 1000 / elapsedMs,
  bytes,
}));

async function issueRequest(url) {
  const response = await fetch(url);
  const body = await response.arrayBuffer();
  if (response.status !== 200) {
    throw new Error(`unexpected status ${response.status}`);
  }
  return body.byteLength;
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const value = argv[i + 1];
    if (value && !value.startsWith("--")) {
      out[key] = value;
      i += 1;
    } else {
      out[key] = "true";
    }
  }
  return out;
}
