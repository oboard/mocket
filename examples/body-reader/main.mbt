///|
using @crescent {type HttpResponse}

///|
struct Csv(String)

///|
impl @crescent.BodyReader for Csv with from_request(req) -> Csv {
  let text : String = req.body()
  Csv(text)
}

///|
struct UserInput {
  name : String
  email : String
} derive(FromJson, ToJson)

///|
async fn main {
  let app = @crescent.Mocket()

  // Custom BodyReader: parse CSV from request body
  app.post("/csv", event => {
    let csv : Csv = event.req.body() catch { _ => Csv("") }
    HttpResponse::ok().body(csv.0)
  })

  // Typed JSON: parse body into a struct with derive(FromJson)
  app.post("/json", event => {
    let user : UserInput = event.req.json()
    HttpResponse::ok().json_value(user)
  })

  // Print Server URL
  for path in app.routes() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000) catch {
    err => println("Server error: \{err}")
  }
}
