///|
#deprecated("use `Mocket::listen(address)` instead")
pub async fn Mocket::serve(self : Mocket, port~ : Int) -> Unit noraise {
  serve_ffi(self, port~)
}

///|
pub async fn Mocket::listen(self : Mocket, address : String) -> Unit noraise {
  listen_ffi(self, address)
}
