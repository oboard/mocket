///|
fn main {
  let app = @mocket.new()

  // Register global middleware
  app
  ..use_middleware(event => println(
    "📝 Request: \{event.req.reqMethod} \{event.req.url}",
  ))

  // Text Response
  ..get("/", _event => "⚡️ Tadaa!")

  // JSON Response
  ..get("/json", _event => { "name": "John Doe", "age": 30, "city": "New York" })

  // Async Response
  ..get("/async_data", async fn(_event) noraise {
    { "name": "John Doe", "age": 30, "city": "New York" }
  })

  // Dynamic Routes
  // /hello2/World = Hello, World!
  ..get("/hello/:name", fn(event) {
    let name = event.params.get("name").unwrap_or("World")
    "Hello, \{name}!"
  })
  // /hello2/World = Hello, World!
  ..get("/hello2/*", fn(event) {
    let name = event.params.get("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Wildcard Routes
  // /hello3/World/World = Hello, World/World!
  ..get("/hello3/**", fn(event) {
    let name = event.params.get("_").unwrap_or("World")
    "Hello, \{name}!"
  })

  // Echo Server
  ..post("/echo", e => e.req.body.to_json())

  // 404 Page
  ..get("/404", e => {
    e.res.statusCode = 404
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

  // Serve
  ..serve(port=4000)

  // Print Server URL
  for path in app.mappings.keys() {
    println("http://localhost:4000\{path.1}")
  }
}
