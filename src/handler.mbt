///|
pub type HttpHandler = async (HttpEvent) -> HttpBody noraise

///|
pub(all) struct WebSocketPeer {
  connection_id : String
  mut subscribed_channels : Array[String]
}

///|
pub fn WebSocketPeer::send(self : WebSocketPeer, message : String) -> Unit {
  // 真正发送到后端连接
  ws_send(self.connection_id, message)
}

///|
pub fn WebSocketPeer::subscribe(self : WebSocketPeer, channel : String) -> Unit {
  if not(self.subscribed_channels.contains(channel)) {
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
  for i = 0; i < self.subscribed_channels.length(); i = i + 1 {
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
pub enum WebSocketEvent {
  Open(WebSocketPeer)
  Message(WebSocketPeer, HttpBody)
  Close(WebSocketPeer)
}

///|
// WebSocket 路由的事件处理器类型（不返回 HttpBody）
pub type WebSocketHandler = (WebSocketEvent) -> Unit
