///|
pub async fn Mocket::serve(self : Mocket, port~ : Int) -> Unit noraise {
  serve_ffi(self, port~)
}
