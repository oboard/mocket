///|
fn main {
  let app = @mocket.new()
  app.use_middleware(logger_middleware)
  // Register global middleware
  app.static_assets("/", @static_file.new("./"))

  // Text Response
  app.get("/", _event => "⚡️ Tadaa!")

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.serve(port=4000)
}

///|
pub async fn logger_middleware(
  event : @mocket.MocketEvent,
  next : async () -> &@mocket.Responder noraise,
) -> &@mocket.Responder noraise {
  let start_time = @env.now()
  let res = next()
  let duration = @env.now() - start_time
  println("\{event.req.http_method} \{event.req.url} - \{duration}ms")
  res
}
