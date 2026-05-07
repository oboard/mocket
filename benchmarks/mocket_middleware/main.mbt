///|
async fn main {
  let port = benchmark_port()
  let app = @mocket_lib.new()

  app.use_middleware(noop_middleware())
  for i = 0; i < 1000; i = i + 1 {
    app.use_middleware(noop_middleware(), base_path="/x\{i}")
  }
  app.use_middleware(noop_middleware(), base_path="/api")
  for i = 0; i < 1000; i = i + 1 {
    app.use_middleware(noop_middleware(), base_path="/api/x\{i}")
  }

  app
  ..get("/plaintext", _ => "Hello, World!")
  ..get("/api/plaintext", _ => "Hello, World!")
  ..get("/json", _ => ({ "message": "Hello, World!" } : Json))
  ..get("/echo/:name", event => event.params.get("name").unwrap_or("World"))
  .post("/echo", event => event.req)

  app.listen("0.0.0.0:\{port}")
}

///|
fn noop_middleware() -> @mocket_lib.Middleware {
  (_event, next) => next()
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
