///|
using @mocket {type HttpResponse}

///|
struct Person {
  name : String
  age : Int
} derive(ToJson, FromJson)

///|
impl @mocket.BodyReader for Person with from_request(req) -> Person raise {
  @json.from_json(req.body())
}

///|
fn main {
  let app = @mocket.new()

  // Text Response
  app
  ..get("/", _event => "⚡️ Tadaa!")

  // Object Response
  ..get("/json", _event => { name: "oboard", age: 21 }.to_json())

  // JSON Request
  // curl --location 'localhost:4000/json' \
  // --header 'Content-Type: application/json' \
  // --data '{
  //     "name": "oboard",
  //     "age": 21
  // }'
  ..post("/json", event => try {
    let person : Person = event.req.body()
    HttpResponse::new(OK).body(
      "Hello, \{person.name}. You are \{person.age} years old.",
    )
  } catch {
    _ => HttpResponse::new(BadRequest).body("Invalid JSON")
  })

  // Echo Server
  ..post("/echo", e => e.req)

  // 404 Page
  ..get("/404", _ => HttpResponse::new(NotFound).body(
    @mocket.html(
      (
        #|<html>
        #|<body>
        #|  <h1>404</h1>
        #|</body>
        #|</html>
      ),
    ),
  ))

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}
