# Mocket

A production-quality web framework for MoonBit, built on `moonbitlang/async`.

Native-first, type-safe, AI-agent friendly.

## Quick Start

```moonbit
async fn main {
  let app = @mocket.new()
  app.get("/", _ => "Hello, Mocket!")
  app.serve_async(port=4000)
}
```

## Features

### Routing

```moonbit
app.get("/users", _ => "list users")
app.get("/users/:id", event => event.param("id").unwrap_or("?"))
app.post("/users", event => event.req)
app.group("/api", group => {
  group.get("/hello", _ => "hello from api")
})
```

### Typed JSON (AI-friendly)

Define types once, use everywhere — parse requests and serialize responses automatically:

```moonbit
struct User {
  name : String
  age : Int
} derive(ToJson, FromJson)

// Parse JSON body → typed struct (bad JSON auto-returns 400)
app.post_json("/users", event => {
  let user : User = event.req.json()
  HttpResponse::created().json_value(user)
})

// Route params with type conversion
app.get_json("/users/:id", event => {
  let id = match event.param_int("id") {
    Some(id) => id
    None => raise HttpError(BadRequest, "invalid id")
  }
  HttpResponse::ok().json_value(find_user(id))
})
```

Errors are automatically mapped to JSON responses:
- `HttpError(status, msg)` → `{"error":{"status":400,"message":"..."}}`
- JSON parse errors → 400 Bad Request
- Unknown errors → 500 Internal Server Error

### Middleware

```moonbit
// Global middleware
app.use_middleware(security_headers())

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

### Response Helpers

```moonbit
HttpResponse::ok()                              // 200
HttpResponse::created()                         // 201
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

```moonbit
async test "api returns user" {
  let app = new()
  app.get("/hello", _ => "Hello!")
  let client = TestClient::new(app)
  let res = client.get("/hello")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "Hello!")
}
```

### Security

```moonbit
app.use_middleware(security_headers())
// Sets: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy
```

Plus: cookie sanitization, request body size limits, request timeouts.

## Full-Stack MoonBit

MoonBit compiles to both **native** (backend) and **JS** (frontend). Define shared
types with `derive(ToJson, FromJson)` and use them on both sides — the API contract
is the type definition itself, no code generation needed.

## Package Structure

```
oboard/mocket           — Framework core (routing, middleware, serving, WebSocket)
oboard/mocket/http      — HTTP protocol utilities (headers, dates, URL encoding)
oboard/mocket/cors      — CORS middleware
oboard/mocket/fetch     — HTTP client
oboard/mocket/static_file — Filesystem static file provider
oboard/mocket/uri       — RFC 3986 URI parser
```

## Running

```bash
moon run examples/route --target native
```

Visit http://localhost:4000

## License

Apache-2.0
