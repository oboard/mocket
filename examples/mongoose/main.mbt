///|
fn main {
  let app = @mocket.new()

  app
  ..get("/", _ => "Hello from Mongoose")
  ..get("/json", _ => ({ "backend": "mongoose", "status": "ok" } : Json))
  .post("/echo", event => {
    let body : Bytes = event.req.body() catch { _ => b"" }
    body
  })

  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4010\{path.1}")
  }

  @mongoose_backend.listen(app, "0.0.0.0:4010")
}
