# Crescent

A web framework for MoonBit. Native-first, type-safe, AI-agent friendly.

> Hard fork of [oboard/mocket](https://github.com/oboard/mocket) by
> [oboard](https://github.com/oboard). [Credits](#credits) at the bottom.

> **Target:** native only. Crescent's HTTP/WebSocket runtime depends on
> `moonbitlang/async/{http,socket,websocket}`, which are not available on the
> wasm or js targets. Use `moon build`/`moon test` (which default to the
> `preferred-target: "native"` declared in `moon.mod.json`) or pass
> `--target native` explicitly.

## Install

```bash
moon add bobzhang/crescent
```

## Hello World

```moonbit
async fn main {
  let app = @crescent.Mocket()
  app.get("/", _ => "Hello, Crescent!")
  app.serve(port=4000)
}
```

```bash
moon run . --target native
# Visit http://localhost:4000
```

---

## Building a Todo API

This walkthrough builds a complete REST API step by step.

### Define your types

Types with `derive(ToJson, FromJson)` are your API contract. The same types
compile to native (backend) and JS (frontend) — no code generation needed.

```moonbit
struct Todo {
  id : Int
  title : String
  done : Bool
} derive(ToJson, FromJson)

struct CreateTodo {
  title : String
} derive(FromJson)
```

### Wire up the routes

All handlers automatically map errors to JSON — bad JSON returns 400,
`raise HttpError(...)` returns a structured error, anything else returns 500.
You never write error-handling boilerplate.

```moonbit
fn build_app() -> @crescent.Mocket {
  let app = @crescent.Mocket()
  let todos : Array[Todo] = [{ id: 1, title: "Learn MoonBit", done: false }]
  let next_id = Ref(2)

  // List all
  app.get("/api/todos", _ =>
    HttpResponse::ok().json_value(todos)
  )

  // Get by ID — require_param_int auto-returns 400 for "abc"
  app.get("/api/todos/:id", event => {
    let id = event.require_param_int("id")
    for todo in todos {
      if todo.id == id {
        return HttpResponse::ok().json_value(todo)
      }
    }
    raise HttpError(NotFound, "todo \{id} not found")
  })

  // Create — event.json() auto-returns 400 for invalid JSON
  app.post("/api/todos", event => {
    let input : CreateTodo = event.json()
    let todo = Todo::{ id: next_id.val, title: input.title, done: false }
    next_id.val += 1
    todos.push(todo)
    HttpResponse::created().json_value(todo)
  })

  // Health check — get_raw for handlers that never raise
  app.get_raw("/health", fn(_) noraise { "ok" })

  app
}
```

### Add middleware

Register middleware before routes. They execute in onion order (first registered
= outermost layer).

```moonbit
fn build_app() -> @crescent.Mocket {
  let app = @crescent.Mocket()

  // Security headers on every response
  app.use_middleware(@crescent.security_headers())

  // Unique request ID for distributed tracing
  app.use_middleware(@crescent.request_id())

  // Request logging
  app.use_middleware(fn(event, next) {
    let start = @async.now()
    let res = next()
    let ms = @async.now() - start
    println("\{event.req.http_method} \{event.req.url} \{ms}ms")
    res
  })

  // Auth only on /api routes
  app.use_middleware(
    fn(event, next) {
      match event.req.get_header("Authorization") {
        Some(_) => next()
        None => HttpResponse::unauthorized()
      }
    },
    base_path="/api",
  )

  // ... register routes ...
  app
}
```

### Test without a network

`TestClient` dispatches requests in-process. No ports, no sockets, fast CI.

```moonbit
async test "create a todo" {
  let app = build_app()
  let client = TestClient(app)

  let res = client.post("/api/todos",
    body=b"{\"title\":\"Write tests\"}")
  assert_eq(res.status, Created)

  let todo : Todo = res.body_json()
  assert_eq(todo.title, "Write tests")
  assert_eq(todo.done, false)
}

async test "invalid ID returns 400" {
  let client = TestClient(build_app())
  let res = client.get("/api/todos/abc")
  assert_eq(res.status, BadRequest)
}

async test "missing todo returns 404" {
  let client = TestClient(build_app())
  let res = client.get("/api/todos/999")
  assert_eq(res.status, NotFound)
}

async test "bad JSON returns 400" {
  let client = TestClient(build_app())
  let res = client.post("/api/todos", body=b"not json")
  assert_eq(res.status, BadRequest)
}

async test "security headers are present" {
  let client = TestClient(build_app())
  let res = client.get("/health")
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
}
```

### Start the server

```moonbit
async fn main {
  let app = build_app()
  println("Listening on http://localhost:4000")
  app.serve(port=4000)
}
```

Try it:

```bash
curl localhost:4000/api/todos
curl -X POST localhost:4000/api/todos -d '{"title":"Write docs"}'
curl localhost:4000/api/todos/1
curl localhost:4000/api/todos/abc       # 400: must be a valid integer
curl -X POST localhost:4000/api/todos -d 'not json'  # 400: parse error
curl localhost:4000/health              # "ok"
```

---

## CRUD with resource()

When your API follows REST conventions, register all 5 routes in one call:

```moonbit
  app.resource("/api/todos", ResourceConfig(
    list   = fn(_) { HttpResponse::ok().json_value(all_todos()) },
    get    = fn(e) {
      let id = e.require_param_int("id")
      HttpResponse::ok().json_value(find_todo(id))
    },
    create = fn(e) {
      let input : CreateTodo = e.json()
      HttpResponse::created().json_value(insert_todo(input))
    },
    update = fn(e) {
      let id = e.require_param_int("id")
      let input : CreateTodo = e.json()
      HttpResponse::ok().json_value(update_todo(id, input))
    },
    delete = fn(e) {
      let id = e.require_param_int("id")
      delete_todo(id)
      HttpResponse::no_content()
    },
  ))
```

This registers `GET /api/todos`, `GET /api/todos/:id`, `POST /api/todos`,
`PUT /api/todos/:id`, `DELETE /api/todos/:id`. All handlers omitted from
`ResourceConfig(...)` are simply not registered.

---

## Route Groups

Share a path prefix and middleware across related routes:

```moonbit
  app.group("/api/v1", fn(api) {
    api.use_middleware(require_auth())

    api.get("/users", _ => HttpResponse::ok().json_value(users))
    api.get("/users/:id", fn(event) {
      let id = event.require_param_int("id")
      HttpResponse::ok().json_value(find_user(id))
    })
    api.post("/users", fn(event) {
      let user : CreateUser = event.json()
      HttpResponse::created().json_value(save_user(user))
    })
  })
  // Routes: GET /api/v1/users, GET /api/v1/users/:id, POST /api/v1/users
  // require_auth() only runs for /api/v1/* requests
```

## Route Patterns

| Pattern | Example URL | Captures |
|---------|-------------|----------|
| `/users` | `/users` | (exact match) |
| `/users/:id` | `/users/42` | `event.param("id")` = `"42"` |
| `/users/:id/posts/:pid` | `/users/1/posts/99` | two params |
| `/files/*` | `/files/readme.txt` | one segment in `_` |
| `/static/**` | `/static/css/main.css` | any depth in `_` |

Matching uses a radix tree — O(path length), not O(number of routes).

---

## WebSocket

```moonbit
  app.ws("/chat", fn(event) {
    match event {
      Open(peer) => {
        println("Connected: \{peer.to_string()}")
        peer.subscribe("chat-room")
      }
      Message(peer, Text(msg)) =>
        peer.publish("chat-room", msg)  // broadcast to all subscribers
      Message(peer, Binary(data)) =>
        peer.binary(data)               // echo binary back
      Close(peer) =>
        println("Disconnected: \{peer.to_string()}")
    }
  })
```

`WebSocketPeer` methods: `text(msg)`, `binary(data)`, `subscribe(channel)`,
`unsubscribe(channel)`, `publish(channel, msg)`.

## Static Files

```moonbit
  app.static_assets("/assets", @static_file.StaticFileProvider(path="./public"))
```

Features: ETag caching, `If-Modified-Since` / `If-None-Match` support,
`Accept-Encoding` content negotiation, path traversal protection,
directory index fallback (`index.html`, `index.htm`, ...).

## Cookies

```moonbit
  // Set with attributes
  event.res.set_cookie("session", "abc123",
    max_age=3600, http_only=true, same_site=Lax)

  // Read
  let user = match event.req.get_cookie("session") {
    Some(cookie) => find_user_by_session(cookie.value)
    None => anonymous_user()
  }

  // Delete (sets Max-Age=0)
  event.res.delete_cookie("session")
```

## HTTP Client (Fetch)

Make outbound HTTP requests from your handlers:

```moonbit
  app.get("/api/weather/:city", fn(event) {
    let city = event.require_param("city")
    let res = @fetch.get("https://api.weather.example/v1/\{city}")
    let weather : WeatherData = res.read_body()
    HttpResponse::ok().json_value(weather)
  })
```

Methods: `@fetch.get`, `@fetch.post`, `@fetch.put`, `@fetch.patch`,
`@fetch.delete`, `@fetch.head`. All accept optional `data`, `headers`,
`credentials`, and `mode` parameters.

## CORS

```moonbit
  // Allow all origins (default)
  app.use_middleware(@cors.handle_cors())

  // Restrict to specific origin
  app.use_middleware(@cors.handle_cors(
    origin="https://myapp.com",
    methods="GET,POST",
    credentials=true,
    max_age=3600,
  ))
```

## Server Configuration

### Request limits

```moonbit
  app.serve_with(port=4000, NativeServeOptions(
    max_connections=1000,               // concurrent connection limit
    max_request_body_bytes=1_048_576,   // 1MB body size limit (413 if exceeded)
    request_body_read_timeout_ms=5000,  // 5s read timeout (408 if exceeded)
  ))
```

### WebSocket options

```moonbit
  app.serve_with(port=4000, NativeServeOptions(
    websocket_max_message_bytes=65536,         // max inbound message size
    websocket_outgoing_queue_capacity=100,     // outbound buffer per connection
    websocket_overflow_policy=DropOldest,      // or DropLatest
    websocket_read_timeout_ms=30000,           // close idle connections after 30s
  ))
```

### Graceful shutdown

```moonbit
  let shutdown = @async.Queue()

  // In another task: shutdown.put(()) to stop the server
  app.serve_until(port=4000, shutdown~)
```

### Serve on an existing server

```moonbit
  let addr = @socket.Addr::parse("0.0.0.0:4000")
  let server = @http.Server::new(addr, reuse_addr=true)
  app.serve_on(server)
```

---

## Response Helpers

```moonbit
  HttpResponse::ok()                           // 200
  HttpResponse::created()                      // 201
  HttpResponse::no_content()                   // 204
  HttpResponse::bad_request()                  // 400
  HttpResponse::unauthorized()                 // 401
  HttpResponse::forbidden()                    // 403
  HttpResponse::not_found()                    // 404
  HttpResponse::error(BadRequest, "message")   // JSON error body
  HttpResponse::redirect("/new-path")          // 301
  HttpResponse::redirect_temporary("/temp")    // 302
  HttpResponse::redirect_307("/preserve")      // 307 (preserves method)
  HttpResponse::redirect_308("/permanent")     // 308 (permanent, preserves method)

  // Fluent chaining
  HttpResponse::ok()
    .header("Cache-Control", "max-age=3600")
    .json_value(data)
```

## Error Handling

All `get`/`post`/`put`/`patch`/`delete` handlers catch errors automatically:

| What you write | What the client gets |
|----------------|---------------------|
| `raise HttpError(BadRequest, "invalid email")` | 400 `{"error":{"status":400,"message":"invalid email"}}` |
| `raise HttpError(NotFound, "not found")` | 404 with JSON body |
| `event.json()` on bad input | 400 with parse error message |
| `event.require_param_int("id")` on `"abc"` | 400 `"must be a valid integer"` |
| Any unhandled error | 500 Internal Server Error |

For handlers that should never raise (health checks, plain text), use `get_raw`:

```moonbit
  app.get_raw("/health", fn(_) noraise { "ok" })
```

For custom error responses, use `try_json`:

```moonbit
  app.post("/users", fn(event) {
    match event.try_json() {
      Ok(user) => HttpResponse::ok().json_value(user)
      Err(msg) => HttpResponse::error(BadRequest, "Invalid user: \{msg}")
    }
  })
```

## Built-in Middleware

| Middleware | What it does |
|-----------|-------------|
| `security_headers()` | `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `X-XSS-Protection: 0`, `Referrer-Policy: strict-origin-when-cross-origin` |
| `request_id()` | Adds `X-Request-Id` header; preserves incoming IDs for distributed tracing. Access via `event.request_id()` |
| `@cors.handle_cors()` | Full CORS support: preflight `OPTIONS` handling, configurable origins/methods/credentials |

Writing custom middleware:

```moonbit
  fn rate_limiter() -> Middleware {
    let count = Ref(0)
    fn(event, next) {
      count.val += 1
      if count.val > 100 {
        return HttpResponse::error(TooManyRequests, "slow down")
      }
      next()
    }
  }
```

---

## API Quick Reference

### Parameters

| Method | Returns | On missing/invalid |
|--------|---------|-------------------|
| `event.param("name")` | `String?` | `None` |
| `event.param_int("id")` | `Int?` | `None` |
| `event.param_int64("id")` | `Int64?` | `None` |
| `event.require_param("name")` | `String` | raises 400 |
| `event.require_param_int("id")` | `Int` | raises 400 |
| `event.require_param_int64("id")` | `Int64` | raises 400 |

### Body & Query

| Method | Returns | Notes |
|--------|---------|-------|
| `event.json[T]()` | `T` | Raises on invalid JSON |
| `event.try_json[T]()` | `Result[T, String]` | For custom error handling |
| `event.req.body[T]()` | `T` | Via `BodyReader` trait (`String`, `Bytes`, `Json`) |
| `event.req.get_query("key")` | `String?` | URL-decoded, cached |
| `event.req.query_params()` | `Map[String, String]` | All query params, cached |
| `event.req.path()` | `String` | Path without query string, cached |
| `event.req.content_type()` | `String?` | Content-Type header value |
| `event.request_id()` | `String?` | Requires `request_id()` middleware |

### HttpMethod Enum

Pattern match on the request method — no string comparisons:

```moonbit
  match event.req.http_method {
    Get => "read"
    Post | Put | Patch => "write"
    Delete => "delete"
    _ => "other"
  }
```

## Performance

- **Radix tree routing** — O(path length) dynamic route lookup
- **Pre-compiled patterns** — route templates parsed at registration, not per request
- **Cached parsing** — path and query string parsed once per request
- **Zero-alloc headers** — case-insensitive ASCII comparison without string allocation
- **Direct byte output** — `Bytes` and `HttpResponse` skip the intermediate buffer

## Packages

```
bobzhang/crescent             — Core: routing, middleware, serving, WebSocket
bobzhang/crescent/http        — HTTP protocol: headers, dates, URL encoding
bobzhang/crescent/cors        — CORS middleware
bobzhang/crescent/fetch       — HTTP client
bobzhang/crescent/static_file — Static file provider (filesystem)
bobzhang/crescent/uri         — RFC 3986 URI parser
```

## Credits

Crescent is a hard fork of [oboard/mocket](https://github.com/oboard/mocket) by
[oboard](https://github.com/oboard). The original framework established the core
architecture: Express-style routing, onion middleware, WebSocket support, static
file serving, and the async-native design built on `moonbitlang/async`.

## License

Apache-2.0
