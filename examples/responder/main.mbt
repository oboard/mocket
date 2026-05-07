///|
using @mocket {type HttpResponse}

///|
async fn main {
  let app = @mocket.new()

  // Text Response
  app
  ..get("/", _event => "⚡️ Tadaa!")

  // Object Response
  ..get("/json", _event => {
    Json::object({ "name": Json::string("oboard"), "age": Json::number(21) })
  })

  // JSON Request
  // curl --location 'localhost:4000/json' \
  // --header 'Content-Type: application/json' \
  // --data '{
  //     "name": "oboard",
  //     "age": 21
  // }'
  ..post("/json", event => {
    try {
      let payload : Json = event.req.json()
      guard payload is Object(obj) else {
        return HttpResponse::new(BadRequest).body("Invalid JSON")
      }
      guard obj.get("name") is Some(String(name)) else {
        return HttpResponse::new(BadRequest).body("Invalid JSON")
      }
      guard obj.get("age") is Some(Number(age, ..)) else {
        return HttpResponse::new(BadRequest).body("Invalid JSON")
      }
      "Hello, \{name}. You are \{age.to_int()} years old."
    } catch {
      _ => return HttpResponse::new(BadRequest).body("Invalid JSON")
    }
  })

  // Echo Server
  ..post("/echo", e => e.req)

  // 404 Page
  .get("/404", _ => {
    HttpResponse::new(NotFound).body(
      @mocket.html(
        (
          #|<html>
          #|<body>
          #|  <h1>404</h1>
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
  app.listen(":4000")
}
