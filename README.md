# oboard/mocket

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A//mooncakes.io/assets/oboard/mocket/resource.json&query=%24.meta_info.version&label=mooncakes&color=yellow)](https://mooncakes.io/docs/oboard/mocket)
[![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/oboard/mocket/check.yaml)](https://github.com/oboard/mocket/actions/workflows/check.yaml)
[![License](https://img.shields.io/github/license/oboard/mocket)](https://github.com/oboard/mocket/blob/main/LICENSE)


A web framework for MoonBit.

![logo](logo.jpg)

## Quick Start

Mocket supports both `js` and `native` backends.

### JavaScript Backend

Set the backend of MoonBit to `js` in `Visual Studio Code`

Command: `MoonBit: Select Backend` -> `js`

```bash
moon run src/example --target js
```

### Native Backend

Set the backend of MoonBit to `native` in `Visual Studio Code`

Command: `MoonBit: Select Backend` -> `native`

```bash
moon run src/example --target native
```

Then visit http://localhost:4000

## Usage

Minimum Example: https://github.com/oboard/mocket_example

## Features

### Dynamic Routes

Support named parameters with `:param` syntax:

```moonbit
app.get("/hello/:name", fn(event) {
  let name = event.params.get("name").or("World")
  Text("Hello, \{name}!")
})
```

### Wildcard Routes

Support single and double wildcards:

```moonbit
// Single wildcard - matches one path segment
app.get("/hello/*", fn(event) {
  let name = event.params.get("_").or("World")
  Text("Hello, \{name}!")
})

// Double wildcard - matches multiple path segments
app.get("/hello/**", fn(event) {
  let path = event.params.get("_").or("")
  Text("Hello, \{path}!")
})
```

### Async Support

The library supports async/await for I/O operations:

### Async /GET Example

```moonbit
// async json data example
app.get("/async_data", async fn(event) {
  Json({ "name": "John Doe", "age": 30, "city": "New York" })
})
```

### Route Groups

Group related routes under a common base path with shared middleware:

```moonbit
app.group("/api", group => {
  // Add group-level middleware
  group.use_middleware(event => println(
    "🔒 API Group Middleware: \{event.req.reqMethod} \{event.req.url}",
  ))
  
  // Routes under /api prefix
  group.get("/hello", _ => Text("Hello from API!"))
  group.get("/users", _ => Json({ "users": ["Alice", "Bob"] }))
  group.post("/data", e => e.req.body)
})
```

This creates routes:
- `GET /api/hello`
- `GET /api/users` 
- `POST /api/data`

All routes in the group will execute the group middleware in addition to any global middleware.

## Example usage

```moonbit
let app = @mocket.new(logger=@mocket.new_debug_logger())

  // Register global middleware
  app
  ..use_middleware(event => println(
    "📝 Request: \{event.req.http_method} \{event.req.url}",
  ))

  // Text Response
  ..get("/", _event => Text("⚡️ Tadaa!"))

  // Hello World
  ..on("GET", "/hello", _ => Text("Hello world!"))
  ..group("/api", group => {
    // 添加组级中间件
    group.use_middleware(event => println(
      "🔒 API Group Middleware: \{event.req.http_method} \{event.req.url}",
    ))
    group.get("/hello", _ => Text("Hello world!"))
    group.get("/json", _ => Json({
      "name": "John Doe",
      "age": 30,
      "city": "New York",
    }))
  })

  // JSON Response
  ..get("/json", _event => Json({
    "name": "John Doe",
    "age": 30,
    "city": "New York",
  }))

  // Async Response
  ..get("/async_data", async fn(_event) noraise {
    Json({ "name": "John Doe", "age": 30, "city": "New York" })
  })

  // Dynamic Routes
  // /hello2/World = Hello, World!
  ..get("/hello/:name", fn(event) {
    let name = event.params.get("name").unwrap_or("World")
    Text("Hello, \{name}!")
  })
  // /hello2/World = Hello, World!
  ..get("/hello2/*", fn(event) {
    let name = event.params.get("_").unwrap_or("World")
    Text("Hello, \{name}!")
  })

  // Wildcard Routes
  // /hello3/World/World = Hello, World/World!
  ..get("/hello3/**", fn(event) {
    let name = event.params.get("_").unwrap_or("World")
    Text("Hello, \{name}!")
  })

  // Echo Server
  ..post("/echo", e => e.req.body)

  // 404 Page
  ..get("/404", e => {
    e.res.status_code = 404
    HTML(
      (
        #|<html>
        #|<body>
        #|  <h1>404</h1>
        #|</body>
        #|</html>
      ),
    )
  })

  // Serve
  ..serve(port=4000)

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }
```

## Route Matching Examples

| Route Pattern | URL | Parameters |
|---------------|-----|------------|
| `/hello/:name` | `/hello/world` | `name: "world"` |
| `/hello/*` | `/hello/world` | `_: "world"` |
| `/hello/**` | `/hello/foo/bar` | `_: "foo/bar"` |
| `/users/:id/posts/:postId` | `/users/123/posts/456` | `id: "123"`, `postId: "456"` |
| `/api/**` | `/api/v1/users/123` | `_: "v1/users/123"` |
| `group("/api", ...).get("/hello")` | `/api/hello` | - |
| `group("/users", ...).get("/:id")` | `/users/123` | `id: "123"` |

## Q & A
### Why not moonbitlang/async ?

moonbitlang/async is a great library, but it is not supported by the js backend.

🙌快来吧！🙌

QQ 群号：**949886784**

![QQ 群](qrcode.jpg)
