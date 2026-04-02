///|
fn wasm_websocket_peer() -> WebSocketPeer {
  WebSocketPeer::{ connection_id: "", subscribed_channels: [] }
}

///|
fn keep_websocket_symbols_alive() -> Unit {
  ignore(WebSocketEvent::Open(wasm_websocket_peer()))
  ignore(
    WebSocketEvent::Message(
      wasm_websocket_peer(),
      WebSocketAggregatedMessage::Text(""),
    ),
  )
  ignore(WebSocketEvent::Close(wasm_websocket_peer()))
  ignore(WebSocketAggregatedMessage::Binary(b""))
  ignore(WebSocketAggregatedMessage::Ping)
}

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  ignore(mocket.find_route("GET", "/"))
  ignore(port)
  keep_websocket_symbols_alive()
  panic()
}

///|
pub fn ws_send(id : String, msg : String) -> Unit {
  ignore(id)
  ignore(msg)
  panic()
}

///|
pub fn ws_send_bytes(id : String, msg : Bytes) -> Unit {
  ignore(id)
  ignore(msg)
  panic()
}

///|
pub fn ws_pong(id : String) -> Unit {
  ignore(id)
  panic()
}

///|
pub fn ws_subscribe(id : String, channel : String) -> Unit {
  ignore(id)
  ignore(channel)
  panic()
}

///|
pub fn ws_unsubscribe(id : String, channel : String) -> Unit {
  ignore(id)
  ignore(channel)
  panic()
}

///|
pub fn ws_publish(channel : String, msg : String) -> Unit {
  ignore(channel)
  ignore(msg)
  panic()
}
