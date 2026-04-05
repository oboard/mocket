# Mocket Performance Notes

## Current Benchmark (Apple M4, release build, 50K requests, 100 concurrent)

| Server                           | Req/sec | Latency (avg) |
|----------------------------------|---------|---------------|
| Node.js http (baseline)          | 101,570 | 1.0ms         |
| Raw MoonBit async (no framework) | 52,644  | 1.9ms         |
| **Mocket** (full framework)      | 24,368  | 4.1ms         |

## Bottleneck Analysis

### 1. MoonBit async runtime vs Node.js (~2x gap)

The async library's HTTP parser converts every header key/value and request
path from UTF-8 bytes to UTF-16 `String` on each request, and the response
sender converts back from UTF-16 to UTF-8. Node.js avoids this — its HTTP
parser (llhttp) works on raw bytes in C and converts to JS strings lazily.

**Once MoonBit optimizes UTF-8 encoding/decoding, the native compilation
advantages (no GC pauses, no JIT warmup) should close this gap.**

### 2. Mocket framework overhead (~2.2x on top of raw async)

Inherent cost of routing, middleware dispatch, and response building.
Already optimized: WebSocket check skip, body read skip for GET, middleware
fast-path, Date header caching, `write_string_utf8` for responders.

## Future Optimization Opportunities

### Use `Map::get_from_string` to avoid StringView-to-String allocations

`Map[String, V]` provides `get_from_string(map, view)` which queries using
a `StringView` without allocating a `String`. This can be applied in:

- **Route lookup** (`path_match.mbt`): `static_routes.get(method)` and
  `routes.get(path)` currently require `String` keys. Changing the route
  matching to use `get_from_string` with `StringView` would eliminate
  allocations in the hot path.
- **Header lookup** (`http/headers.mbt`): Header name comparisons could
  use `StringView` instead of converting to `String` via `.to_lower()`.
- **Middleware path matching**: `path_scope_matches` could take `StringView`.

### Avoid copying request headers

`handle_request_async` copies the entire request headers `Map` via
`copy_async_headers()` (line ~494 in `serve_async_native.mbt`). This is
needed because users might mutate `event.req.headers`. A possible optimization:

- Use a copy-on-write wrapper that only copies when mutated.
- Or make `HttpRequest.headers` read-only and provide explicit mutation APIs.

### Pre-compute request path

`HttpRequest::path()` calls `request_target_path()` which parses the URL
each time. The path is also computed in `handle_request_async` for routing.
Caching the parsed path on the `HttpRequest` struct would avoid duplicate work
when middleware calls `event.req.path()`.

### Reduce allocation in `send_response_async`

The response path creates a `@buffer.Buffer`, writes the responder output,
then calls `buffer.to_bytes()` to get the body. This double-copies the data.
The `Responder` trait could be redesigned to write directly to the connection's
writer, eliminating the intermediate buffer for simple string responses.

### Route matching with precompiled patterns

Currently, dynamic routes iterate through all registered patterns and call
`match_path()` on each. Precompiling route patterns into a trie or radix tree
would give O(path_length) lookup instead of O(num_routes × path_length).
