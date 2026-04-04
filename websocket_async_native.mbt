///|
priv struct NativeWebSocketConnection {
  outgoing : @async.Queue[NativeWebSocketOutbound]
  subscribed_channels : Map[String, Unit]
}

///|
priv enum NativeWebSocketOutbound {
  SendText(String)
  SendBinary(Bytes)
}

///|
let native_ws_connections : Map[String, NativeWebSocketConnection] = Map::new()

///|
let native_ws_channels : Map[String, Map[String, Unit]] = Map::new()

///|
let native_ws_connection_counter : Ref[Int] = Ref::new(0)

///|
const NATIVE_WS_OUTGOING_QUEUE_CAPACITY : Int = 256

///|
fn next_native_ws_connection_id() -> String {
  native_ws_connection_counter.val += 1
  native_ws_connection_counter.val.to_string()
}

///|
fn snapshot_native_ws_channels(connection_id : String) -> Array[String] {
  match native_ws_connections.get(connection_id) {
    Some(connection) => {
      let channels : Array[String] = []
      connection.subscribed_channels.each((channel, _) => channels.push(channel))
      channels
    }
    None => []
  }
}

///|
fn snapshot_native_ws_peer(connection_id : String) -> WebSocketPeer {
  {
    connection_id,
    subscribed_channels: snapshot_native_ws_channels(connection_id),
  }
}

///|
fn register_native_ws_connection(
  connection_id : String,
  outgoing : @async.Queue[NativeWebSocketOutbound],
) -> Unit {
  native_ws_connections.set(connection_id, {
    outgoing,
    subscribed_channels: Map::new(),
  })
}

///|
fn remove_native_ws_channel_member(
  channel : String,
  connection_id : String,
) -> Unit {
  match native_ws_channels.get(channel) {
    Some(members) => {
      if members.get(connection_id) is Some(_) {
        ignore(members.remove(connection_id))
      }
      if members.is_empty() {
        ignore(native_ws_channels.remove(channel))
      }
    }
    None => ()
  }
}

///|
fn unregister_native_ws_connection(connection_id : String) -> Unit {
  match native_ws_connections.get(connection_id) {
    Some(connection) => {
      let channels = snapshot_native_ws_channels(connection_id)
      for channel in channels {
        remove_native_ws_channel_member(channel, connection_id)
      }
      connection.outgoing.close()
      ignore(native_ws_connections.remove(connection_id))
    }
    None => ()
  }
}

///|
fn enqueue_native_ws_outgoing(
  connection_id : String,
  message : NativeWebSocketOutbound,
) -> Unit {
  match native_ws_connections.get(connection_id) {
    Some(connection) => ignore(try? connection.outgoing.try_put(message))
    None => ()
  }
}

///|
pub fn ws_send(id : String, msg : String) -> Unit {
  enqueue_native_ws_outgoing(id, SendText(msg))
}

///|
pub fn ws_send_bytes(id : String, msg : Bytes) -> Unit {
  enqueue_native_ws_outgoing(id, SendBinary(msg))
}

///|
pub fn ws_pong(id : String) -> Unit {
  ignore(id)
  abort(
    "WebSocketPeer::pong() is not supported on the native async runtime; ping/pong is handled internally by moonbitlang/async/websocket",
  )
}

///|
pub fn ws_subscribe(id : String, channel : String) -> Unit {
  match native_ws_connections.get(id) {
    Some(connection) => {
      if connection.subscribed_channels.get(channel) is Some(_) {
        return
      }
      connection.subscribed_channels.set(channel, ())
      match native_ws_channels.get(channel) {
        Some(members) => members.set(id, ())
        None => {
          let members : Map[String, Unit] = Map::new()
          members.set(id, ())
          native_ws_channels.set(channel, members)
        }
      }
    }
    None => ()
  }
}

///|
pub fn ws_unsubscribe(id : String, channel : String) -> Unit {
  match native_ws_connections.get(id) {
    Some(connection) => {
      if connection.subscribed_channels.get(channel) is Some(_) {
        ignore(connection.subscribed_channels.remove(channel))
      }
      remove_native_ws_channel_member(channel, id)
    }
    None => ()
  }
}

///|
pub fn ws_publish(channel : String, msg : String) -> Unit {
  match native_ws_channels.get(channel) {
    Some(members) => {
      let connection_ids : Array[String] = []
      members.each((connection_id, _) => connection_ids.push(connection_id))
      for connection_id in connection_ids {
        ws_send(connection_id, msg)
      }
    }
    None => ()
  }
}

///|
pub fn __ws_emit(
  _event_type : @native.CStr,
  _connection_id : @native.CStr,
  _payload : @native.CStr,
) -> Unit {

}

///|
async fn write_native_ws_outgoing(
  ws : @websocket.Conn,
  outgoing : @async.Queue[NativeWebSocketOutbound],
) -> Unit {
  for ;; {
    let next = outgoing.get() catch { _ => break }
    match next {
      SendText(text) => ws.send_text(text)
      SendBinary(data) => ws.send_binary(data)
    }
  }
}

///|
async fn handle_websocket_route_async(
  request : @http.Request,
  conn : @http.ServerConnection,
  handler : WebSocketHandler,
) -> Unit raise Error {
  let ws = @websocket.from_http_server(request, conn)
  defer ws.close()
  let connection_id = next_native_ws_connection_id()
  let outgoing = @async.Queue::new(
    kind=DiscardOldest(NATIVE_WS_OUTGOING_QUEUE_CAPACITY),
  )
  register_native_ws_connection(connection_id, outgoing)
  @async.with_task_group(group => {
    group.spawn_bg(() => write_native_ws_outgoing(ws, outgoing))
    handler(Open(snapshot_native_ws_peer(connection_id)))
    for ;; {
      let message_result : Result[@websocket.Message, Error] = try? ws.recv()
      let message = match message_result {
        Ok(message) => message
        Err(@websocket.ConnectionClosed(_, _)) => break
        Err(err) => raise err
      }
      let peer = snapshot_native_ws_peer(connection_id)
      match message.kind {
        Text => handler(Message(peer, Text(message.read_all().text())))
        Binary => handler(Message(peer, Binary(message.read_all().binary())))
      }
    }
    outgoing.close()
  }) catch {
    err => {
      handler(Close(snapshot_native_ws_peer(connection_id)))
      unregister_native_ws_connection(connection_id)
      raise err
    }
  }
  handler(Close(snapshot_native_ws_peer(connection_id)))
  unregister_native_ws_connection(connection_id)
}
