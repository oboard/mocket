///|
/// Starts serving HTTP requests on the given port, blocking the current thread.
pub fn Mocket::serve_blocking(self : Mocket, port~ : Int) -> Unit {
  async_run(async fn() noraise {
    self.serve(port~) catch {
      err => println("Mocket native server error: \{err}")
    }
  })
}
