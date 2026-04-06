///|
fn main {
  let app = @crescent.Mocket()
  app.use_middleware(logger_middleware())
  // Register global middleware
  app.static_assets("/", @static_file.StaticFileProvider(path="./"))

  // Text Response
  app.get("/", _ => "Tadaa!")

  // Print Server URL
  for path in app.routes() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve_blocking(port=4000)
}

///|
fn logger_middleware() -> @crescent.Middleware {
  (event, next) => {
    let start_time = @async.now()
    let res = next()
    let duration = @async.now() - start_time
    println("\{event.req.http_method} \{event.req.url} - \{duration}ms")
    res
  }
}
