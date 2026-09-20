///|
#deprecated("use `Mocket::listen(address)` instead")
pub async fn App::serve(self : App, port~ : Int) -> Unit noraise {
  serve_ffi(self, port~)
}

///|
pub async fn App::listen(self : App, address : String) -> Unit noraise {
  listen_ffi(self, address)
}
