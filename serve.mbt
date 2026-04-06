///|
/// Starts serving HTTP requests on the given port, blocking the current thread.
pub fn Mocket::serve_blocking(self : Mocket, port~ : Int) -> Unit {
  serve_ffi(self, port~)
}
