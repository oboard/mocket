///|
struct Person {
  name : String
  age : Int
} derive(ToJson)

///|
fn main {
  let app = @mocket.new()

  // Text Response
  app
  ..get("/", _event => "⚡️ Tadaa!")

  // Object Response
  ..get("/", _event => { name: "oboard", age: 21 }.to_json())

  // Echo Server
  ..post("/echo", e => e.req)

  // 404 Page
  ..get("/404", _ => @mocket.HttpResponse::new(@mocket.NotFound).body(
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
