import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import { createInterface } from "node:readline";

const args = parseArgs(process.argv.slice(2));
const requests = Number(args.requests ?? 10_000);
const warmup = Number(args.warmup ?? 200);
const port = Number(args.port ?? 3200);
const payloadBytes = Number(args["payload-bytes"] ?? 128);
const url = `http://127.0.0.1:${port}/payload`;

const clients = [
  {
    name: "mio",
    check: ["moon", ["version"]],
    command: "moon",
    args: [
      "run",
      "benchmarks/clients/mio",
      "--",
      "--url",
      url,
      "--requests",
      String(requests),
      "--warmup",
      String(warmup),
    ],
  },
  {
    name: "node",
    check: ["node", ["--version"]],
    command: "node",
    args: [
      "benchmarks/clients/node/client.mjs",
      "--url",
      url,
      "--requests",
      String(requests),
      "--warmup",
      String(warmup),
    ],
  },
  {
    name: "bun",
    check: ["bun", ["--version"]],
    command: "bun",
    args: [
      "benchmarks/clients/bun/client.js",
      "--url",
      url,
      "--requests",
      String(requests),
      "--warmup",
      String(warmup),
    ],
  },
  {
    name: "go",
    check: ["go", ["version"]],
    command: "go",
    args: [
      "run",
      ".",
      "--url",
      url,
      "--requests",
      String(requests),
      "--warmup",
      String(warmup),
    ],
    cwd: "benchmarks/clients/go",
  },
  {
    name: "hyper",
    check: ["cargo", ["--version"]],
    command: "cargo",
    args: [
      "run",
      "--release",
      "--manifest-path",
      "benchmarks/clients/hyper/Cargo.toml",
      "--",
      "--url",
      url,
      "--requests",
      String(requests),
      "--warmup",
      String(warmup),
    ],
  },
];

const server = spawn("node", [
  "benchmarks/server.mjs",
  "--port",
  String(port),
  "--payload-bytes",
  String(payloadBytes),
], {
  stdio: ["ignore", "pipe", "inherit"],
});

try {
  await waitForReady(server);
  console.log(`server: ${url} (${payloadBytes} bytes)`);

  const results = [];
  for (const client of clients) {
    if (!commandAvailable(client.check[0], client.check[1])) {
      console.log(`${client.name}: skipped (${client.check[0]} not found)`);
      continue;
    }
    process.stdout.write(`${client.name}: running... `);
    const result = runClient(client);
    results.push(result);
    console.log(`${result.requests_per_sec.toFixed(0)} req/s`);
  }

  printTable(results);
} finally {
  server.kill("SIGTERM");
  await once(server, "exit").catch(() => {});
}

async function waitForReady(child) {
  const rl = createInterface({ input: child.stdout });
  for await (const line of rl) {
    const message = JSON.parse(line);
    if (message.event === "ready") return;
  }
  throw new Error("benchmark server exited before ready");
}

function runClient(client) {
  const proc = spawnSync(client.command, client.args, {
    cwd: client.cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (proc.status !== 0) {
    throw new Error(
      `${client.name} failed\nstdout:\n${proc.stdout}\nstderr:\n${proc.stderr}`,
    );
  }
  const line = proc.stdout.trim().split("\n").at(-1);
  return JSON.parse(line);
}

function commandAvailable(command, args) {
  const proc = spawnSync(command, args, {
    encoding: "utf8",
    stdio: "ignore",
  });
  return proc.status === 0;
}

function printTable(results) {
  if (results.length === 0) return;
  const sorted = [...results].sort(
    (a, b) => b.requests_per_sec - a.requests_per_sec,
  );
  console.log("\nRuntime   Requests/sec   Elapsed ms   Bytes");
  console.log("-------   ------------   ----------   -----");
  for (const result of sorted) {
    console.log(
      [
        result.runtime.padEnd(8),
        result.requests_per_sec.toFixed(0).padStart(12),
        result.elapsed_ms.toFixed(2).padStart(10),
        String(result.bytes).padStart(7),
      ].join("   "),
    );
  }
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
