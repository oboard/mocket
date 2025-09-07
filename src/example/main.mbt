///|
fn main {
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
}
