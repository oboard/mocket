# oboard/mocket

A web framework for MoonBit.

![logo](logo.jpg)

![screenshots](screenshots/1.png)

## Quick Start

```bash
moon run src/main/main.mbt --target js
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
  "Hello, \{name}!"
})
```

### Wildcard Routes

Support single and double wildcards:

```moonbit
// Single wildcard - matches one path segment
app.get("/hello/*", fn(event) {
  let name = event.params.get("_").or("World")
  "Hello, \{name}!"
})

// Double wildcard - matches multiple path segments
app.get("/hello/**", fn(event) {
  let path = event.params.get("_").or("")
  "Hello, \{path}!"
})
```

### Async Support

The library supports async/await for I/O operations:

- `readFile`: Asynchronously read files
- `readDir`: Asynchronously read directories
- `exec`: Asynchronously execute commands
- `fetch`: Asynchronously make HTTP requests

Async functions can be called using the `!!` operator and must be wrapped in
`run_async` when called from synchronous contexts.

### Async /GET Example

```moonbit
// async json data example
app.get("/async_data", async fn(event) {
  { "name": "John Doe", "age": 30, "city": "New York" }
})
```

```moonbit
run_async(fn() {
  try {
    let result = @mocket.exec!!("ls")
    println(result)
  } catch {
    err => println("Error executing command: \{err}")
  }
})
run_async(fn() {
  try {
    let response = @mocket.fetch!!("https://api64.ipify.org/")
    println(response)
  } catch {
    err => println("Error fetching data: \{err}")
  }
})
```

## Error Handling

Async operations return `Result` types or use the `!` error type syntax:

- `readFile`: Returns `Bytes!Error`
- `exec`: Returns `String!Error`
- `fetch`: Returns `FetchResponse!NetworkError`

Use `try/catch` blocks to handle potential errors.

## Example usage

```moonbit
fn main {
  let app = @mocket.new()

  // Text Response
  app.get("/", _event => "⚡️ Tadaa!")

  // JSON Response
  app.get("/json", _event => {
    "name": "John Doe",
    "age": 30,
    "city": "New York",
  })

  // Async Response
  app.get("/async_data", async fn(_event) {
    { "name": "John Doe", "age": 30, "city": "New York" }
  })

  // Dynamic Routes
  app.get("/hello/:name", fn(event) {
    let name = event.params.get("name").or("World")
    "Hello, \{name}!"
  })

  // Wildcard Routes
  app.get("/hello/*", fn(event) {
    let name = event.params.get("_").or("World")
    "Hello, \{name}!"
  })

  app.get("/hello/**", fn(event) {
    let path = event.params.get("_").or("")
    "Hello, \{path}!"
  })

  // Echo Server
  app.post("/echo", e => e.req.body.to_json())

  // 404 Page
  app.get("/404", e => {
    e.res.statusCode = 404
    @mocket.html(
      #|<html>
      #|<body>
      #|  <h1>404</h1>
      #|</body>
      #|</html>
      ,
    )
  })

  // Serve
  app.serve(port=4000)

  // Print Server URL
  println("http://localhost:4000")
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

🙌快来吧！🙌

QQ 群号：**949886784**

![QQ群](qrcode.jpg)
