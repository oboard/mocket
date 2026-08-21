///|
async fn main {
  let app = @mocket.new()
  app.use_middleware(logger_middleware())
  // Register global middleware.
  // The mount is "/", so every URL enters the static middleware; with
  // fallthrough enabled, requests that match no asset (like the explicit
  // route below) continue to the router instead of getting a 404.
  app.static_assets("/", @static_file.new("./", fallthrough=true))

  // Text Response
  app.get("/", _event => "⚡️ Tadaa!")

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.listen("0.0.0.0:4000")
}

///|
fn logger_middleware() -> @mocket.Middleware {
  (event, next) => {
    let start_time = @env.now()
    let res = next()
    let duration = @env.now() - start_time
    println("\{event.req.http_method} \{event.req.url} - \{duration}ms")
    res
  }
}
