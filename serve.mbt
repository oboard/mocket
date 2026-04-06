///|
pub fn Mocket::serve_blocking(self : Mocket, port~ : Int) -> Unit {
  serve_ffi(self, port~)
}
