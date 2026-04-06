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

## Optimizations Applied

### Radix tree routing (replaces linear scan)

Dynamic routes are stored in a radix/prefix tree that gives O(path_length)
lookup instead of the previous O(num_routes * path_length) linear scan.
Static routes still use direct Map lookup for O(1) performance.

### Pre-compiled route patterns

Route templates (e.g. `/users/:id/posts/:postId`) are parsed into a
`CompiledRoute` with `Array[RouteSegment]` at registration time. Per-request
matching iterates the pre-parsed array instead of re-splitting strings.

### Cached path and query parsing

`HttpRequest::path()` and `HttpRequest::query_params()` cache their results
on first access. Since the path is accessed by routing, middleware scope
matching, and user handler code, this eliminates duplicate parsing.

### Zero-allocation header comparison

`header_name_matches()` compares ASCII characters in-place instead of
allocating two new strings via `.to_lower()` on every comparison.

### Direct byte output (output_bytes)

The `Responder` trait has an `output_bytes()` method that returns pre-encoded
bytes directly, bypassing the intermediate `Buffer` allocation for types that
already hold their response as bytes (HttpResponse, Bytes).

### Efficient header copy

Request headers are copied from the async runtime using `Map::from_iter`
for bulk construction instead of per-key `set()` insertion.

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
`Map::from_iter`. This is needed because middleware may mutate
`event.req.headers`. A possible optimization:

- Use a copy-on-write wrapper that only copies when mutated.
- Or make `HttpRequest.headers` read-only and provide explicit mutation APIs.

### Pre-compute request path

The path is now cached after first access via `HttpRequest::path()`, but
it could be pre-computed at request construction time in `handle_request_async`
since the path is always needed for routing.

### Reduce allocation in response path

For simple string responses, the data flows through:
`String -> Buffer -> Bytes -> connection`. The `output_bytes()` optimization
helps for Bytes/HttpResponse, but String responses still go through the
buffer. A `Responder::write_to(writer)` method that writes directly to
the connection would eliminate the intermediate buffer entirely.
