///|
#deprecated("use `Mocket::listen(address)` instead")
pub fn Mocket::serve(self : Mocket, port~ : Int) -> Unit noraise {
  serve_ffi(self, port~)
}

///|
pub fn Mocket::listen(self : Mocket, address : String) -> Unit noraise {
  listen_ffi(self, address)
}

///|
fn listen_port(address : String) -> Int {
  match address.rev_split_once(":") {
    Some((_, port_text)) => @string.parse_int(port_text) catch { _ => 0 }
    None => @string.parse_int(address) catch { _ => 0 }
  }
}
