///|
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
  // /hello2/World = Hello, World!
  app.get("/hello/:name", fn(event) {
    let name = event.params.get("name").or("World")
    "Hello, \{name}!"
  })
  // /hello2/World = Hello, World!
  app.get("/hello2/*", fn(event) {
    let name = event.params.get("_").or("World")
    "Hello, \{name}!"
  })

  // Wildcard Routes
  // /hello3/World/World = Hello, World/World!
  app.get("/hello3/**", fn(event) {
    let name = event.params.get("_").or("World")
    "Hello, \{name}!"
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
