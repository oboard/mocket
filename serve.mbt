///|
#deprecated("use `Mocket::listen(address)` instead")
pub fn Mocket::serve(self : Mocket, port~ : Int) -> Unit noraise {
  serve_ffi(self, port~)
}

///|
pub fn Mocket::listen(self : Mocket, address : String) -> Unit noraise {
  listen_ffi(self, address)
}
