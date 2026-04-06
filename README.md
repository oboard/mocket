# Crescent

A web framework for MoonBit. Native-first, type-safe, AI-agent friendly.

> Hard fork of [oboard/mocket](https://github.com/oboard/mocket) by
> [oboard](https://github.com/oboard). Credits at the bottom.

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

## Building a JSON API

This walkthrough builds a todo API from scratch, introducing features as you need them.

### Step 1: Define your types

Define types once with `derive(ToJson, FromJson)`. These serve as your API contract
— the same types work on both backend (native) and frontend (JS).

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

### Step 2: Register routes

Handlers automatically map errors to JSON responses — bad JSON returns 400,
`HttpError` returns structured errors, unknown errors return 500.

```moonbit
async fn main {
  let app = @crescent.Mocket()
  let todos : Array[Todo] = [{ id: 1, title: "Learn MoonBit", done: false }]
  let next_id = Ref(2)

  // List all todos
  app.get("/api/todos", _ =>
    HttpResponse::ok().json_value(todos)
  )

  // Get one by ID (auto 400 if ID is not a valid integer)
  app.get("/api/todos/:id", event => {
    let id = event.require_param_int("id")
    for todo in todos {
      if todo.id == id {
        return HttpResponse::ok().json_value(todo)
      }
    }
    raise HttpError(NotFound, "todo not found")
  })

  // Create (auto 400 if body is not valid JSON)
  app.post("/api/todos", event => {
    let input : CreateTodo = event.json()
    let todo = { id: next_id.val, title: input.title, done: false }
    next_id.val += 1
    todos.push(todo)
    HttpResponse::created().json_value(todo)
  })

  app.serve(port=4000)
}
```

That's a working CRUD API. Try it:

```bash
curl localhost:4000/api/todos
curl -X POST localhost:4000/api/todos -d '{"title":"Write docs"}'
curl localhost:4000/api/todos/1
curl localhost:4000/api/todos/abc    # -> 400 "must be a valid integer"
curl -X POST localhost:4000/api/todos -d 'not json'  # -> 400
```

### Step 3: Add middleware

```moonbit
  // Security headers on all responses
  app.use_middleware(security_headers())

  // Request ID for tracing
  app.use_middleware(request_id())

  // Logging (custom middleware)
  app.use_middleware((event, next) => {
    let start = @async.now()
    let res = next()
    let ms = @async.now() - start
    println("\{event.req.http_method} \{event.req.url} \{ms}ms")
    res
  })

  // Auth only for /api routes
  app.use_middleware(auth_check(), base_path="/api")
```

### Step 4: Test without a server

`TestClient` dispatches requests in-process — no ports, no network, fast CI.

```moonbit
async test "create and list todos" {
  let app = build_app()  // same function that builds your real app
  let client = TestClient(app)

  // Create
  let res = client.post("/api/todos",
    body=b"{\"title\":\"Test todo\"}")
  assert_eq(res.status, Created)
  let todo : Todo = res.body_json()
  assert_eq(todo.title, "Test todo")

  // List
  let res2 = client.get("/api/todos")
  let todos : Array[Todo] = res2.body_json()
  assert_true(todos.length() > 0)
}
```

### Step 5: Use resource() for standard CRUD

If your API follows REST conventions, `resource()` registers all 5 routes in one call:

```moonbit
  app.resource("/api/todos", ResourceConfig(
    list=handler_list,
    get=handler_get,
    create=handler_create,
    update=handler_update,
    delete=handler_delete,
  ))
  // Registers:
  //   GET    /api/todos        -> list
  //   GET    /api/todos/:id    -> get
  //   POST   /api/todos        -> create
  //   PUT    /api/todos/:id    -> update
  //   DELETE /api/todos/:id    -> delete
```

## Route Groups

Organize routes with shared prefixes and middleware:

```moonbit
  app.group("/api/v1", group => {
    group.use_middleware(auth_middleware())
    group.get("/users", _ => "list users")
    group.get("/users/:id", event => {
      let id = event.require_param_int("id")
      HttpResponse::ok().json_value(find_user(id))
    })
  })
```

## Route Patterns

| Pattern | Example | Matches |
|---------|---------|---------|
| `/users` | Static | Exact match only |
| `/users/:id` | Named param | `/users/42` — `event.param("id")` = `"42"` |
| `/files/*` | Single wildcard | `/files/readme.txt` — one segment |
| `/static/**` | Multi wildcard | `/static/css/main.css` — any depth |

## WebSocket

```moonbit
  app.ws("/chat", event => {
    match event {
      Open(peer) => peer.subscribe("room-1")
      Message(peer, Text(msg)) => peer.publish("room-1", msg)
      Close(_) => ()
    }
  })
```

Peers support `text()`, `binary()`, `subscribe()`, `unsubscribe()`, and `publish()`.

## Static Files

```moonbit
  app.static_assets("/assets", @static_file.StaticFileProvider(path="./public"))
```

Built-in: ETag caching, If-Modified-Since, Accept-Encoding negotiation,
path traversal protection, directory index fallback.

## Cookies

```moonbit
  // Set
  event.res.set_cookie("session", "abc123",
    max_age=3600, http_only=true, same_site=Lax)

  // Read
  match event.req.get_cookie("session") {
    Some(cookie) => cookie.value
    None => "anonymous"
  }

  // Delete
  event.res.delete_cookie("session")
```

## HTTP Client

```moonbit
  let res = @fetch.get("https://api.example.com/data")
  let data : MyType = res.read_body()

  let res = @fetch.post("https://api.example.com/users",
    data=user.to_json(), headers={ "Authorization": "Bearer token" })
```

## Response Helpers

```moonbit
  HttpResponse::ok()                              // 200
  HttpResponse::created()                         // 201
  HttpResponse::no_content()                      // 204
  HttpResponse::bad_request()                     // 400
  HttpResponse::not_found()                       // 404
  HttpResponse::error(BadRequest, "message")      // JSON error body
  HttpResponse::redirect("/new-path")             // 301
  HttpResponse::redirect_temporary("/temp")       // 302

  // Fluent chaining
  HttpResponse::ok()
    .header("X-Custom", "value")
    .json_value(data)
```

## Error Handling

All `get`/`post`/`put`/`patch`/`delete` handlers catch errors automatically:

| Error | HTTP Response |
|-------|--------------|
| `raise HttpError(BadRequest, "msg")` | 400 `{"error":{"status":400,"message":"msg"}}` |
| `raise HttpError(NotFound, "msg")` | 404 with JSON body |
| JSON parse failure | 400 Bad Request |
| Any other error | 500 Internal Server Error |

For handlers that should never error (e.g. health checks), use `get_raw`:

```moonbit
  app.get_raw("/health", fn(_) noraise { "ok" })
```

For custom error handling, use `try_json`:

```moonbit
  app.get("/users", event => {
    match event.try_json() {
      Ok(user) => HttpResponse::ok().json_value(user)
      Err(msg) => HttpResponse::error(BadRequest, "Custom: \{msg}")
    }
  })
```

## Built-in Middleware

| Middleware | What it does |
|-----------|-------------|
| `security_headers()` | X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy |
| `request_id()` | Adds `X-Request-Id` to request and response; preserves existing IDs |
| `@cors.handle_cors()` | CORS preflight and response headers |

## API Quick Reference

### Parameter Extraction

| Method | Returns | On missing/invalid |
|--------|---------|-------------------|
| `event.param("name")` | `String?` | `None` |
| `event.param_int("id")` | `Int?` | `None` |
| `event.require_param("name")` | `String` | 400 error |
| `event.require_param_int("id")` | `Int` | 400 error |

### Body Parsing

| Method | Returns | Notes |
|--------|---------|-------|
| `event.json[T]()` | `T` | Raises on invalid JSON |
| `event.try_json[T]()` | `Result[T, String]` | For custom error handling |
| `event.req.body[T]()` | `T` | Via `BodyReader` trait |
| `event.req.get_query("key")` | `String?` | URL-decoded, cached |
| `event.req.path()` | `String` | Path without query, cached |

### HttpMethod Enum

```moonbit
  match event.req.http_method {
    Get => ...
    Post => ...
    Put | Patch => ...
    Delete => ...
    _ => ...
  }
```

## Performance

- **Radix tree routing** — O(path_length) dynamic route lookup
- **Pre-compiled patterns** — route templates parsed once at registration
- **Cached parsing** — path and query string parsed once per request
- **Zero-alloc headers** — case-insensitive comparison without allocation
- **Direct byte output** — skips intermediate buffer for Bytes/HttpResponse

## Package Structure

```
bobzhang/crescent             — Core (routing, middleware, serving, WebSocket)
bobzhang/crescent/testing     — Test client (alternative import)
bobzhang/crescent/http        — HTTP protocol utilities
bobzhang/crescent/cors        — CORS middleware
bobzhang/crescent/fetch       — HTTP client
bobzhang/crescent/static_file — Filesystem static file provider
bobzhang/crescent/uri         — RFC 3986 URI parser
```

## Full-Stack MoonBit

MoonBit compiles to both **native** (backend) and **JS** (frontend). Define types
with `derive(ToJson, FromJson)` and use them on both sides — the type definition
is the API contract, no code generation needed.

## Credits

Crescent is a hard fork of [oboard/mocket](https://github.com/oboard/mocket) by
[oboard](https://github.com/oboard). The original framework established the core
architecture: Express-style routing, onion middleware, WebSocket support, static
file serving, and the async-native design built on `moonbitlang/async`.

## License

Apache-2.0
