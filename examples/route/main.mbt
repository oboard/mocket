///|
fn main {
  let app = @mocket.new()

  // Register global middleware
  app
  ..use_middleware(logger_middleware())
  ..use_middleware(@cors.handle_cors())

  // Text Response
  ..get("/", _event => "⚡️ Tadaa!")

  // Hello World
  ..on("GET", "/hello", _ => "Hello world!")
  ..group("/api", group => {
    // 添加组级中间件
    group.use_middleware((event, next) => {
      println(
        "🔒 API Group Middleware: \{event.req.http_method} \{event.req.url}",
      )
      next()
    })
    group.get("/hello", _ => "Hello world!")
    group.get("/json", _ => (
      { "name": "John Doe", "age": 30, "city": "New York" } : Json))
  })

  // JSON Response
  ..get("/json", _event => (
    { "name": "John Doe", "age": 30, "city": "New York" } : Json))

  // Async Response
  ..get("/async_data", async fn(_event) noraise {
    ({ "name": "John Doe", "age": 30, "city": "New York" } : Json)
  })

  // Dynamic Routes
  // /hello2/World = Hello, World!
  ..get("/hello/:name", event => {
    let name = event.params.get("name").unwrap_or("World")
    "Hello, \{name}!"
  })
  // /hello2/World = Hello, World!
  ..get("/hello2/*", event => {
    let name = event.params.get("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Wildcard Routes
  // /hello3/World/World = Hello, World/World!
  ..get("/hello3/**", event => {
    let name = event.params.get("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Echo Server
  ..post("/echo", e => e.req)

  // 404 Page
  ..use_middleware(not_found_middleware())

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}

///|
pub fn not_found_middleware() -> @mocket.Middleware {
  (event, next) => {
    let res = next()
    res.options(event.res)
    if event.res.status_code == NotFound {
      @mocket.html(
        (
          #|<html>
          #|<body>
          #|  <h1>Custom 404</h1>
          #|</body>
          #|</html>
        ),
      )
    } else {
      res
    }
  }
}

///|
fn logger_middleware() -> @mocket.Middleware {
  (event, next) => {
    let start_time = @env.now()
    let res = next()
    let duration = @env.now() - start_time
    println("\{event.req.http_method} \{event.req.url} - \{duration}ms")
    res
  }
}
