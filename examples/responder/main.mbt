///|
using @crescent {type HttpResponse}

///|
struct Person {
  name : String
  age : Int
} derive(ToJson, FromJson)

///|
fn main {
  let app = @crescent.new()

  // Text Response
  app
  ..get("/", _ => "Tadaa!")

  // Object Response using json_value
  ..get("/json", _ => HttpResponse::ok().json_value({ name: "oboard", age: 21 }))

  // JSON Request using event.req.json[T]() with post for auto error handling
  // curl --location 'localhost:4000/json' \
  // --header 'Content-Type: application/json' \
  // --data '{
  //     "name": "oboard",
  //     "age": 21
  // }'
  ..post("/json", event => {
    let person : Person = event.req.json()
    HttpResponse::ok().body(
      "Hello, \{person.name}. You are \{person.age} years old.",
    )
  })

  // Echo Server
  ..post("/echo", e => e.req)

  // Error response helpers
  ..get("/error", _ => HttpResponse::error(BadRequest, "Something went wrong"))

  // 404 Page
  .get("/404", _ => {
    HttpResponse::not_found().body(
      @crescent.html(
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
  app.serve_blocking(port=4000)
}
