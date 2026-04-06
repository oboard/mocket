///|
using @mocket {type HttpResponse}

///|
struct Csv(String)

///|
impl @mocket.BodyReader for Csv with from_request(req) -> Csv {
  let text : String = req.body()
  Csv(text)
}

///|
struct UserInput {
  name : String
  email : String
} derive(FromJson, ToJson)

///|
fn main {
  let app = @mocket.new()

  // Custom BodyReader: parse CSV from request body
  app.post("/csv", event => {
    let csv : Csv = event.req.body() catch { _ => Csv("") }
    HttpResponse::ok().body(csv.0)
  })

  // Typed JSON: parse body into a struct with derive(FromJson)
  app.post_json("/json", event => {
    let user : UserInput = event.req.json()
    HttpResponse::ok().json_value(user)
  })

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}
