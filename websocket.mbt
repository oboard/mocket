///|
pub(all) struct WebSocketPeer {
  connection_id : String
  mut subscribed_channels : Array[String]
}

///|
pub fn WebSocketPeer::text(self : WebSocketPeer, message : String) -> Unit {
  // 真正发送到后端连接
  ws_send(self.connection_id, message)
}

///|
pub fn WebSocketPeer::binary(self : WebSocketPeer, message : Bytes) -> Unit {
  // 真正发送到后端连接
  ws_send_bytes(self.connection_id, message)
}

///|
pub fn WebSocketPeer::pong(self : WebSocketPeer) -> Unit {
  // 真正发送到后端连接
  ws_pong(self.connection_id)
}

///|
pub fn WebSocketPeer::subscribe(self : WebSocketPeer, channel : String) -> Unit {
  if !self.subscribed_channels.contains(channel) {
    self.subscribed_channels.push(channel)
    ws_subscribe(self.connection_id, channel)
  }
}

///|
pub fn WebSocketPeer::unsubscribe(
  self : WebSocketPeer,
  channel : String,
) -> Unit {
  let mut index = None
  for i in 0..<self.subscribed_channels.length() {
    if self.subscribed_channels[i] == channel {
      index = Some(i)
      break
    }
  }
  match index {
    Some(i) => {
      ignore(self.subscribed_channels.remove(i))
      ws_unsubscribe(self.connection_id, channel)
    }
    None => ()
  }
}

///|
pub fn WebSocketPeer::publish(channel : String, message : String) -> Unit {
  ws_publish(channel, message)
}

///|
pub fn WebSocketPeer::to_string(self : WebSocketPeer) -> String {
  "WebSocketPeer(\{self.connection_id})"
}

///|
pub(all) enum WebSocketEvent {
  Open(WebSocketPeer)
  Message(WebSocketPeer, WebSocketAggregatedMessage)
  Close(WebSocketPeer)
}

///|
pub(all) enum WebSocketAggregatedMessage {
  Text(String)
  Binary(Bytes)
  Ping
}

///|
// WebSocket 路由的事件处理器类型（不返回 HttpBody）
pub type WebSocketHandler = (WebSocketEvent) -> Unit

///|
#cfg(target="js")
fn websocket_accept_key(key : String) -> String {
  let guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  (key + guid)
  |> @utf8.encode
  |> @crypto.sha1
  |> Bytes::from_array
  |> @base64.encode
}

///|
/// 将 WS 事件类型字符串和 payload 转换为 WebSocketEvent 并调用 handler
pub fn dispatch_ws_event(
  handler : WebSocketHandler,
  peer : WebSocketPeer,
  event_type : String,
  payload : Bytes,
) -> Unit {
  match event_type {
    "open" => handler(Open(peer))
    "message" => handler(Message(peer, Text(@utf8.decode_lossy(payload))))
    "binary" => handler(Message(peer, Binary(payload)))
    "ping" => handler(Message(peer, Ping))
    "close" => handler(Close(peer))
    _ => ()
  }
}
