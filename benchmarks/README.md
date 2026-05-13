# Mocket HTTP Benchmarks

This directory contains equivalent tiny HTTP servers for Mocket and common
web frameworks. The Mocket server is compiled and run on the MoonBit native
backend.

Routes:

- `GET /plaintext` returns `Hello, World!`
- `GET /api/plaintext` returns `Hello, World!` for middleware-focused Mocket runs
- `GET /middleware/plaintext` exercises a real middleware stack where the target supports it
- `GET /api/v1/users/current/profile/settings` exercises a deep static route
- `GET /static/999` exercises lookup in a router with 1000 registered static routes
- `GET /json` returns `{ "message": "Hello, World!" }`
- `GET /echo/:name` returns the path parameter
- `GET /users/:user_id/posts/:post_id/comments/:comment_id` exercises multiple path parameters
- `GET /wild/**` returns the wildcard suffix
- `GET /query?name=moonbit&repeat=4` exercises query-string routing
- `GET /headers` mutates response headers
- `GET /missing` exercises the 404 path
- `POST /echo` echoes the request body
- `POST /json-echo` echoes a JSON request body
- `POST /consume` reads a 16 KiB request body and returns `ok`

Route suites:

- `quick`: `plaintext`, `json`, `echo`
- `routing`: static, deep static, many-route static, dynamic, wildcard, query, and 404 paths
- `body`: small text, JSON, and 16 KiB request-body echo
- `middleware`: dedicated middleware route plus `/api` middleware-index route
- `comprehensive`: broad GET and POST coverage for framework comparison
- `all`: every route case, including middleware-specific cases

Run a quick Mocket-only benchmark:

```sh
python3 benchmarks/run.py --prepare mocket --duration 10 --connections 100
```

Run the comprehensive Mocket suite:

```sh
python3 benchmarks/run.py --prepare mocket --suite comprehensive --duration 10 --connections 100
```

Run all configured targets:

```sh
python3 benchmarks/run.py --prepare --suite comprehensive --duration 30 --connections 256
```

Run a subset:

```sh
python3 benchmarks/run.py --prepare mocket nodejs bun deno gin axum
```

Run the middleware benchmark. For Mocket, the runner starts the internal
middleware profile and reports the result under the `mocket` target:

```sh
python3 benchmarks/run.py --prepare mocket --suite middleware --duration 10 --connections 100
```

Run the MoonBit in-process microbenchmarks:

```sh
moon bench --release --target native -p oboard/mocket -f performance_wbtest.mbt
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
