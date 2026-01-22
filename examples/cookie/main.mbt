///|
fn main {
  let app = @mocket.new()
  app.get("/", e => {
    e.res.set_cookie("session_id", "12345", max_age=3600)
    if e.req.get_cookie("session_id") is Some(session_id) {
      session_id.value
    } else {
      "No session_id"
    }
  })

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:3000\{path.1}")
  }

  // Serve
  app.serve(port=3000)
}
