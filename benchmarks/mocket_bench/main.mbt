///|
async fn main {
  let app = @mocket.new()
  app.get("/text", fn(_event) noraise { "Hello, World!" })
  app.get("/json", fn(_event) noraise {
    ({ "message": "Hello, World!" } : Json)
  })
  app.get("/user/:id", fn(event) noraise {
    let id = event.param("id").unwrap_or("0")
    ({ "id": id, "name": "User \{id}" } : Json)
  })
  println("Mocket server listening on port 3001")
  app.serve_async(port=3001) catch {
    err => println("Server error: \{err}")
  }
}
