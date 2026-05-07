import http from "node:http";

const args = parseArgs(process.argv.slice(2));
const port = Number(args.port ?? process.env.MIO_BENCH_PORT ?? 3200);
const payloadBytes = Number(
  args["payload-bytes"] ?? process.env.MIO_BENCH_PAYLOAD_BYTES ?? 128,
);
const payload = Buffer.alloc(payloadBytes, "m");

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, {
      "Content-Length": "2",
      "Content-Type": "text/plain",
      Connection: "keep-alive",
    });
    res.end("ok");
    return;
  }

  if (req.method !== "GET" || req.url !== "/payload") {
    res.writeHead(404, {
      "Content-Length": "0",
      Connection: "keep-alive",
    });
    res.end();
    return;
  }

  res.writeHead(200, {
    "Content-Length": String(payload.length),
    "Content-Type": "application/octet-stream",
    Connection: "keep-alive",
  });
  res.end(payload);
});

server.keepAliveTimeout = 60_000;
server.headersTimeout = 65_000;

server.listen(port, "127.0.0.1", () => {
  console.log(
    JSON.stringify({
      event: "ready",
      port,
      payload_bytes: payload.length,
    }),
  );
});

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
