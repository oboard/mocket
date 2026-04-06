///|
struct BenchUser {
  id : Int
  name : String
} derive(ToJson, FromJson)

///|
async fn main {
  let app = @mocket.new()

  // Plain text (baseline, same as mocket_bench)
  app.get("/text", _ => "Hello, World!")

  // JSON using old pattern (Json literal)
  app.get("/json-raw", _ => ({ "message": "Hello, World!" } : Json))

  // JSON using typed json_value
  app.get("/json-typed", _ => {
    let user : BenchUser = { id: 1, name: "Alice" }
    @mocket.HttpResponse::ok().json_value(user)
  })

  // POST with typed JSON parsing (get_json + req.json)
  app.post_json("/json-parse", event => {
    let user : BenchUser = event.req.json()
    @mocket.HttpResponse::ok().json_value(user)
  })

  println("Mocket typed benchmark on port 3007")
  app.serve_async(port=3007) catch {
    err => println("Server error: \{err}")
  }
}
