///|
#deprecated("use `Mocket::listen(address)` instead")
pub fn Mocket::serve(self : Mocket, port~ : Int) -> Unit {
  serve_ffi(self, port~)
}

///|
pub fn Mocket::listen(self : Mocket, address : String) -> Unit {
  listen_ffi(self, address)
}
