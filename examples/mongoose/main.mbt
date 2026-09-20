///|
fn main {
  let app = @mocket.App()

  app
  ..get("/", _ => "Hello from Mongoose")
  ..get("/json", _ => ({ "backend": "mongoose", "status": "ok" } : Json))
  .post("/echo", event => {
    let body : Bytes = event.body() catch { _ => b"" }
    body
  })

  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4010\{path.1}")
  }

  @mongoose_backend.listen(app, ":4010")
}
