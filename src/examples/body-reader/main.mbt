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
fn main {
  let app = @mocket.new()

  // Text Response
  app.post("/", event => {
    let csv : Csv = event.req.body() catch { _ => Csv("") }
    HttpResponse::new(OK).body(csv.0)
  })

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}
