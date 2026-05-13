///|
pub fn serve_ffi(_mocket : Mocket, port~ : Int) -> Unit {
  ignore(port)
  // Unimplemented
  panic()
}

///|
pub fn listen_ffi(_mocket : Mocket, address : String) -> Unit {
  ignore(address)
  // Unimplemented
  panic()
}

///|
pub fn ws_send(_id : String, _msg : String) -> Unit {
  ()
}

///|
pub fn ws_send_bytes(_id : String, _msg : Bytes) -> Unit {
  ()
}

///|
pub fn ws_pong(_id : String) -> Unit {
  ()
}

///|
pub fn ws_subscribe(_id : String, _channel : String) -> Unit {
  ()
}

///|
pub fn ws_unsubscribe(_id : String, _channel : String) -> Unit {
  ()
}

///|
pub fn ws_publish(_channel : String, _msg : String) -> Unit {
  ()
}
