///|
fn main {
  let app = @mocket.new(logger=@mocket.new_production_logger())

  // Register global middleware
  app
  ..use_middleware((event, next) => {
    println("📝 Request: \{event.req.http_method} \{event.req.url}")
    next()
  })
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
    group.get("/json", _ => @mocket.json({
      "name": "John Doe",
      "age": 30,
      "city": "New York",
    }))
  })

  // JSON Response
  ..get("/json", _event => @mocket.json({
    "name": "John Doe",
    "age": 30,
    "city": "New York",
  }))

  // Async Response
  ..get("/async_data", async fn(_event) noraise {
    @mocket.json({ "name": "John Doe", "age": 30, "city": "New York" })
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
  ..get("/404", e => {
    e.res.status_code = 404
    @mocket.html(
      (
        #|<html>
        #|<body>
        #|  <h1>404</h1>
        #|</body>
        #|</html>
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
