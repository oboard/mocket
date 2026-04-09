///|
async fn main {
  let app = @crescent.Mocket()
  app.use_middleware(logger_middleware())

  // Mount static files under /assets — any file in ./public is served
  // as /assets/<filename> (e.g. ./public/logo.png → /assets/logo.png).
  // Previously this example mounted at "/" which intercepted the index
  // route below, so the text response was never reached.
  app.static_assets("/assets", @static_file.StaticFileProvider(path="./public"))

  // Text Response at the root
  app.get("/", _ => "Tadaa!")

  // Print Server URL
  for path in app.routes() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000) catch {
    err => println("Server error: \{err}")
  }
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
