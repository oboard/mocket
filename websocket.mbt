/// Represents a connected WebSocket client with its connection ID and subscribed channels.

///|
pub struct WebSocketPeer {
  priv connection_id : String
  priv subscribed_channels : Array[String]

  fn new(connection_id~ : String) -> WebSocketPeer
}

///|
pub fn WebSocketPeer::new(connection_id~ : String) -> WebSocketPeer {
  { connection_id, subscribed_channels: [] }
}

/// Sends a text message to this WebSocket peer.

///|
pub fn WebSocketPeer::text(self : WebSocketPeer, message : String) -> Unit {
  ws_send(self.connection_id, message)
}

/// Sends a binary message to this WebSocket peer.

///|
pub fn WebSocketPeer::binary(self : WebSocketPeer, message : Bytes) -> Unit {
  ws_send_bytes(self.connection_id, message)
}

/// Subscribes this WebSocket peer to the given pub/sub channel.

///|
pub fn WebSocketPeer::subscribe(self : WebSocketPeer, channel : String) -> Unit {
  if !self.subscribed_channels.contains(channel) {
    self.subscribed_channels.push(channel)
  }
  ws_subscribe(self.connection_id, channel)
}

/// Unsubscribes this WebSocket peer from the given pub/sub channel.

///|
pub fn WebSocketPeer::unsubscribe(
  self : WebSocketPeer,
  channel : String,
) -> Unit {
  let mut index = None
  for i, ch in self.subscribed_channels {
    if ch == channel {
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

/// Publishes a text message to a pub/sub channel on behalf of this peer.

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

/// Events delivered to a WebSocket handler: connection open, message received, or connection closed.

///|
pub enum WebSocketEvent {
  Open(WebSocketPeer)
  Message(WebSocketPeer, WebSocketAggregatedMessage)
  Close(WebSocketPeer)
}

/// A fully assembled WebSocket message, either text or binary.

///|
pub enum WebSocketAggregatedMessage {
  Text(String)
  Binary(Bytes)
}

/// Handler function type for WebSocket route events.

///|
// WebSocket route event handler type (does not return HttpBody)
pub type WebSocketHandler = (WebSocketEvent) -> Unit
