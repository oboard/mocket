///|
pub(all) struct WebSocketPeer {
  connection_id : String
  mut subscribed_channels : Array[String]
}

///|
pub fn WebSocketPeer::text(self : WebSocketPeer, message : String) -> Unit {
  ws_send(self.connection_id, message)
}

///|
pub fn WebSocketPeer::binary(self : WebSocketPeer, message : Bytes) -> Unit {
  ws_send_bytes(self.connection_id, message)
}

///|
pub fn WebSocketPeer::subscribe(self : WebSocketPeer, channel : String) -> Unit {
  if !self.subscribed_channels.contains(channel) {
    self.subscribed_channels.push(channel)
  }
  ws_subscribe(self.connection_id, channel)
}

///|
pub fn WebSocketPeer::unsubscribe(
  self : WebSocketPeer,
  channel : String,
) -> Unit {
  let mut index = None
  for i = 0; i < self.subscribed_channels.length(); i = i + 1 {
    if self.subscribed_channels[i] == channel {
      index = Some(i)
      break
    }
  }
  match index {
    Some(i) => ignore(self.subscribed_channels.remove(i))
    None => ()
  }
  ws_unsubscribe(self.connection_id, channel)
}

///|
pub fn WebSocketPeer::publish(
  self : WebSocketPeer,
  channel : String,
  message : String,
) -> Unit {
  ws_publish(self.connection_id, channel, message)
}

///|
pub fn WebSocketPeer::to_string(self : WebSocketPeer) -> String {
  "WebSocketPeer(\{self.connection_id})"
}

///|
pub enum WebSocketEvent {
  Open(WebSocketPeer)
  Message(WebSocketPeer, WebSocketAggregatedMessage)
  Close(WebSocketPeer)
}

///|
pub enum WebSocketAggregatedMessage {
  Text(String)
  Binary(Bytes)
}

///|
// WebSocket route event handler type (does not return HttpBody)
pub type WebSocketHandler = (WebSocketEvent) -> Unit
