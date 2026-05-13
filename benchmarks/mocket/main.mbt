///|
async fn main {
  let port = benchmark_port()
  let app = @mocket_lib.new()
  for i in 0..<1000 {
    app.get("/static/\{i}", _ => "Hello, World!")
  }

  app
  ..get("/plaintext", _ => "Hello, World!")
  ..get("/api/plaintext", _ => "Hello, World!")
  ..get("/api/v1/users/current/profile/settings", _ => "settings")
  ..get("/json", _ => ({ "message": "Hello, World!" } : Json))
  ..get("/echo/:name", event => event.params.get("name").unwrap_or("World"))
  ..get("/users/:user_id/posts/:post_id/comments/:comment_id", event => {
    event.params.get("comment_id").unwrap_or("")
  })
  ..get("/wild/**", event => event.params.get("_").unwrap_or(""))
  ..get("/query", _ => "moonbit")
  ..get("/headers", event => {
    event.res.headers["x-benchmark"] = "mocket"
    "ok"
  })
  ..post("/echo", event => event.req.raw_body)
  ..post("/json-echo", event => {
    event.res.headers["Content-Type"] = "application/json; charset=utf-8"
    event.req.raw_body
  })
  .post("/consume", _ => "ok")

  app.listen("0.0.0.0:\{port}")
}

///|
fn benchmark_port() -> Int {
  match @env.get_env_var("PORT") {
    Some(port_text) => {
      let port : Int = @strconv.from_str(port_text) catch { _ => 3000 }
      port
    }
    None => 3000
  }
}
