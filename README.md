# Crescent

A production-quality web framework for MoonBit, built on `moonbitlang/async`.

Native-first, type-safe, AI-agent friendly.

> **Crescent** is a hard fork of [oboard/mocket](https://github.com/oboard/mocket),
> the original MoonBit web framework by [oboard](https://github.com/oboard).
> We gratefully acknowledge their foundational work — Crescent builds on mocket's
> core design (routing, middleware, WebSocket, static files) and extends it with
> AI-friendly APIs, performance optimizations, and additional features.

## Quick Start

```moonbit
async fn main {
  let app = @crescent.Mocket()
  app.get("/", _ => "Hello, Crescent!")
  app.serve(port=4000)
}
```

## Features

### Routing

```moonbit
app.get("/users", _ => "list users")
app.get("/users/:id", event => {
  let id = event.require_param_int("id")
  HttpResponse::ok().json_value(find_user(id))
})
app.post("/users", event => {
  let user : CreateUser = event.json()
  HttpResponse::created().json_value(user)
})
app.group("/api", group => {
  group.get("/hello", _ => "hello from api")
})
```

Route patterns: static (`/users`), named parameters (`/users/:id`),
single wildcard (`/files/*`), multi-level wildcard (`/static/**`).

Routes are matched using a **radix tree** for O(path_length) lookup performance.

### Type-Safe HttpMethod Enum

The request method is a proper enum, not a string — prevents typos and enables
pattern matching:

```moonbit
match event.req.http_method {
  Get => "reading"
  Post => "creating"
  _ => "other"
}
```

### Typed JSON (AI-friendly)

All `get`/`post`/`put`/`patch`/`delete` handlers automatically map errors
to JSON responses. Define types once, use everywhere:

```moonbit
struct User {
  name : String
  age : Int
} derive(ToJson, FromJson)

// Parse JSON body -> typed struct (bad JSON auto-returns 400)
app.post("/users", event => {
  let user : User = event.json()   // shorthand for event.req.json()
  HttpResponse::created().json_value(user)
})

// Type-safe parameter extraction (auto 400 on invalid)
app.get("/users/:id", event => {
  let id = event.require_param_int("id")
  HttpResponse::ok().json_value(find_user(id))
})
```

Errors are automatically mapped to JSON responses:
- `HttpError(status, msg)` -> `{"error":{"status":400,"message":"..."}}`
- JSON parse errors -> 400 Bad Request
- Unknown errors -> 500 Internal Server Error

For handlers that need no error mapping (e.g. health checks), use `get_raw`:

```moonbit
app.get_raw("/health", fn(_) noraise { "ok" })
```

### try_json for Custom Error Handling

When you need custom error messages instead of automatic mapping:

```moonbit
app.get("/users", event => {
  match event.try_json() {
    Ok(user) => HttpResponse::ok().json_value(user)
    Err(msg) => HttpResponse::error(BadRequest, "Custom: \{msg}")
  }
})
```

### RESTful Resources

Register all 5 CRUD routes in one call:

```moonbit
app.resource("/api/todos", {
  list:   Some(event => HttpResponse::ok().json_value(todos)),
  get:    Some(event => {
    let id = event.require_param_int("id")
    HttpResponse::ok().json_value(find_todo(id))
  }),
  create: Some(event => {
    let input : CreateTodo = event.json()
    HttpResponse::created().json_value(save_todo(input))
  }),
  update: Some(event => {
    let id = event.require_param_int("id")
    let input : UpdateTodo = event.json()
    HttpResponse::ok().json_value(update_todo(id, input))
  }),
  delete: Some(event => {
    let id = event.require_param_int("id")
    delete_todo(id)
    HttpResponse::no_content()
  }),
})
// Registers: GET /api/todos, GET /api/todos/:id, POST, PUT/:id, DELETE/:id
```

### Middleware

```moonbit
// Global middleware
app.use_middleware(security_headers())
app.use_middleware(request_id())

// Path-scoped middleware
app.use_middleware(auth_middleware(), base_path="/api")

// Custom middleware (onion model)
app.use_middleware((event, next) => {
  let start = @async.now()
  let res = next()
  let ms = @async.now() - start
  println("\{event.req.http_method} \{event.req.url} \{ms}ms")
  res
})
```

### Built-in Middleware

| Middleware | Description |
|-----------|-------------|
| `security_headers()` | Sets X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy |
| `request_id()` | Assigns unique X-Request-Id to each request; preserves existing IDs for tracing |
| `@cors.handle_cors()` | CORS preflight and response headers |

### Response Helpers

```moonbit
HttpResponse::ok()                              // 200
HttpResponse::created()                         // 201
HttpResponse::no_content()                      // 204
HttpResponse::bad_request()                     // 400
HttpResponse::not_found()                       // 404
HttpResponse::error(BadRequest, "invalid")      // JSON error body
HttpResponse::redirect("/new-path")             // 301
HttpResponse::redirect_temporary("/temp")       // 302
HttpResponse::ok()
  .header("X-Custom", "value")                  // fluent chaining
  .json_value(data)                             // typed JSON body
```

### WebSocket

```moonbit
app.ws("/chat", event => {
  match event {
    Open(peer) => peer.subscribe("room-1")
    Message(peer, Text(msg)) => peer.publish("room-1", msg)
    Close(_) => ()
  }
})
```

### Static Files

```moonbit
app.static_assets("/assets", StaticFileProvider::new("./public"))
```

Includes: ETag caching, If-Modified-Since, Accept-Encoding negotiation,
path traversal protection, index.html fallback.

### Testing (no network required)

Two ways to import the test client:

```moonbit
// Option 1: from the core package
let client = @crescent.TestClient::new(app)

// Option 2: from the dedicated testing package
let client = @testing.TestClient::new(app)
```

Example tests:

```moonbit
async test "api returns user" {
  let app = new()
  app.get("/hello", _ => "Hello!")
  let client = TestClient::new(app)
  let res = client.get("/hello")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "Hello!")
}

async test "typed json round-trip" {
  let app = new()
  app.post("/users", event => {
    let user : User = event.json()
    HttpResponse::created().json_value(user)
  })
  let client = TestClient::new(app)
  let body = @utf8.encode("{\"name\":\"Alice\",\"age\":30}")
  let res = client.post("/users", body~)
  assert_eq(res.status, Created)
  let user : User = res.body_json()
  assert_eq(user.name, "Alice")
}
```

### Cookies

```moonbit
// Set cookie with attributes
event.res.set_cookie("session", "abc123",
  max_age=3600, http_only=true, same_site=Lax)

// Read cookie
match event.req.get_cookie("session") {
  Some(cookie) => cookie.value
  None => "anonymous"
}

// Delete cookie
event.res.delete_cookie("session")
```

### Security

```moonbit
app.use_middleware(security_headers())
// Sets: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy
```

Plus: cookie sanitization, request body size limits, request timeouts.

### HTTP Client (Fetch)

```moonbit
let res = @fetch.get("https://api.example.com/data")
let data : MyType = res.read_body()

let res = @fetch.post("https://api.example.com/users",
  data=user.to_json(), headers={ "Authorization": "Bearer token" })
```

## API Reference

### Handler Types

| Method | Handler Type | Error Handling |
|--------|-------------|----------------|
| `app.get(path, handler)` | Can raise | Automatic JSON error responses |
| `app.get_raw(path, handler)` | Must be noraise | Manual error handling |

All HTTP methods: `get`, `post`, `put`, `patch`, `delete`, `head`, `options`, `trace`, `connect`, `all`.

### Parameter Extraction

| Method | Returns | On Missing/Invalid |
|--------|---------|-------------------|
| `event.param("name")` | `String?` | `None` |
| `event.param_int("id")` | `Int?` | `None` |
| `event.param_int64("id")` | `Int64?` | `None` |
| `event.require_param("name")` | `String` | Raises HttpError(400) |
| `event.require_param_int("id")` | `Int` | Raises HttpError(400) |
| `event.require_param_int64("id")` | `Int64` | Raises HttpError(400) |

### Body Parsing

| Method | Returns | Notes |
|--------|---------|-------|
| `event.json[T]()` | `T` | Raises on invalid JSON |
| `event.try_json[T]()` | `Result[T, String]` | For custom error handling |
| `event.req.body[T]()` | `T` via BodyReader trait | For String, Bytes, Json |
| `event.req.query_params()` | `Map[String, String]` | Cached after first access |
| `event.req.get_query("key")` | `String?` | Uses cached query params |
| `event.req.path()` | `String` | Cached after first access |

### Request ID

```moonbit
app.use_middleware(request_id())
// In handlers:
let id = event.request_id()  // Some("req-1") or None
```

## Performance

- **Radix tree routing** -- O(path_length) lookup for dynamic routes
- **Pre-compiled route patterns** -- templates parsed once at registration
- **Cached path & query parsing** -- parsed once per request, not per access
- **Zero-alloc header comparison** -- ASCII case-insensitive without `.to_lower()`
- **Direct byte output** -- `output_bytes()` skips buffer for Bytes/HttpResponse
- **Efficient header copy** -- `Map::from_iter` for bulk construction

## Full-Stack MoonBit

MoonBit compiles to both **native** (backend) and **JS** (frontend). Define shared
types with `derive(ToJson, FromJson)` and use them on both sides -- the API contract
is the type definition itself, no code generation needed.

## Package Structure

```
bobzhang/crescent             -- Framework core (routing, middleware, serving, WebSocket)
bobzhang/crescent/testing     -- Test client (alternative import for external users)
bobzhang/crescent/http        -- HTTP protocol utilities (headers, dates, URL encoding)
bobzhang/crescent/cors        -- CORS middleware
bobzhang/crescent/fetch       -- HTTP client
bobzhang/crescent/static_file -- Filesystem static file provider
bobzhang/crescent/uri         -- RFC 3986 URI parser
```

## Running

```bash
moon run examples/route --target native
```

Visit http://localhost:4000

## Credits

Crescent is a hard fork of [oboard/mocket](https://github.com/oboard/mocket) by
[oboard](https://github.com/oboard). The original mocket framework established the
core architecture: Express-style routing, onion middleware, WebSocket support, static
file serving, and the async-native design built on `moonbitlang/async`.

Crescent adds:
- Type-safe `HttpMethod` enum (replaces string methods)
- Raising handlers as default API with automatic error mapping
- `require_param` / `event.json()` / `try_json()` helpers
- `resource()` CRUD helper for RESTful APIs
- Request ID middleware
- Radix tree routing (O(path_length) vs O(n) linear scan)
- Pre-compiled route patterns
- Cached path and query param parsing
- Zero-allocation header comparison
- Direct byte output (skips buffer copy)
- Comprehensive documentation and test coverage (430+ tests)
- Dedicated `testing/` sub-package

## License

Apache-2.0
