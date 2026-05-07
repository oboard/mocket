///|
async fn main {
  let port = benchmark_port()
  let app = @mocket_lib.new()

  app
  ..get("/plaintext", _ => "Hello, World!")
  ..get("/json", _ => ({ "message": "Hello, World!" } : Json))
  ..get("/echo/:name", event => event.params.get("name").unwrap_or("World"))
  .post("/echo", event => event.req)

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
