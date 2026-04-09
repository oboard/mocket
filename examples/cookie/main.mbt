///|
fn main {
  let app = @crescent.Mocket()
  // Demonstrate cookie set/read flow.
  //
  // On the first visit the browser sends no cookies, so we see "new session"
  // and set session_id for the next response. On the second visit the browser
  // sends back session_id=12345 and we greet the returning user.
  app.get("/", e => {
    if e.req.get_cookie("session_id") is Some(session_id) {
      "Welcome back, session: \{session_id.value}"
    } else {
      e.res.set_cookie("session_id", "12345", max_age=3600)
      "new session — reload to see session_id"
    }
  })

  // Print Server URL
  for path in app.routes() {
    println("\{path.0} http://localhost:3000\{path.1}")
  }

  // Serve
  app.serve_blocking(port=3000)
}
