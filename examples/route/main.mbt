///|
fn main {
  let app = @mocket.new()

  // Register global middleware
  app
  ..use_middleware(logger_middleware())
  ..use_middleware(@cors.handle_cors())
  ..use_middleware(@mocket.security_headers())

  // Text Response
  ..get("/", _ => "Tadaa!")

  // Hello World
  ..on("GET", "/hello", _ => "Hello world!")
  ..group("/api", group => {
    // Add group-level middleware
    group.use_middleware((event, next) => {
      println("API Group Middleware: \{event.req.http_method} \{event.req.url}")
      next()
    })
    group.get("/hello", _ => "Hello world!")
    group.get("/json", _ => {
      @mocket.HttpResponse::ok().json_value(
        ({ "name": "John Doe", "age": 30, "city": "New York" } : Json),
      )
    })
  })

  // JSON Response
  ..get("/json", _ => {
    ({ "name": "John Doe", "age": 30, "city": "New York" } : Json)
  })

  // Async Response
  ..get("/async_data", fn(_) noraise {
    ({ "name": "John Doe", "age": 30, "city": "New York" } : Json)
  })

  // Dynamic Routes
  // /hello2/World = Hello, World!
  ..get("/hello/:name", event => {
    let name = event.param("name").unwrap_or("World")
    "Hello, \{name}!"
  })
  // /hello2/World = Hello, World!
  ..get("/hello2/*", event => {
    let name = event.param("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Wildcard Routes
  // /hello3/World/World = Hello, World/World!
  ..get("/hello3/**", event => {
    let name = event.param("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Echo Server
  .post("/echo", e => e.req)

  // Custom 404 handler
  app.set_not_found_handler(_ => {
    @mocket.HttpResponse::not_found().body(
      @mocket.html(
        (
          #|<html>
          #|<body>
          #|  <h1>Custom 404</h1>
          #|</body>
          #|</html>
        ),
      ),
    )
  })

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}

///|
fn logger_middleware() -> @mocket.Middleware {
  (event, next) => {
    let start_time = @async.now()
    let res = next()
    let duration = @async.now() - start_time
    println("\{event.req.http_method} \{event.req.url} - \{duration}ms")
    res
  }
}
