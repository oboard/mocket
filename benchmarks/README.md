# Mocket HTTP Benchmarks

This directory contains equivalent tiny HTTP servers for Mocket and common
web frameworks. The Mocket server is compiled and run on the MoonBit native
backend.

Routes:

- `GET /plaintext` returns `Hello, World!`
- `GET /json` returns `{ "message": "Hello, World!" }`
- `GET /echo/:name` returns the path parameter
- `POST /echo` echoes the request body

Run a quick Mocket-only benchmark:

```sh
python3 benchmarks/run.py --prepare mocket --duration 10 --connections 100
```

Run all configured targets:

```sh
python3 benchmarks/run.py --prepare --duration 30 --connections 256
```

Run a subset:

```sh
python3 benchmarks/run.py --prepare mocket nodejs bun deno gin axum
```

The runner uses `oha` when it is installed. If `oha` is not available, it falls
back to `autocannon` or `npx -y autocannon`. Raw JSON results are written under
`benchmarks/results/`.

External runtime requirements by target:

- `mocket`: `moon`
- `nodejs`: `node`
- `bun`: `bun`
- `deno`: `deno`
- `gin`: `go`
- `axum`: `cargo`
- `springboot`: `mvn` and Java 17+
- `hono`: `node` and `npm`
- `nitro`: `node` and `npm`
- `php`: `php`

Use the same machine, route set, connection count, benchmark duration, and
load generator for every run. Disable background workload and prefer release
or production builds for framework targets.
