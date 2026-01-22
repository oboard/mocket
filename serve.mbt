///|
pub fn Mocket::serve(self : Mocket, port~ : Int) -> Unit {
  serve_ffi(self, port~)
}
