///|
priv struct NativeWebSocketConnection {
  outgoing : @async.Queue[NativeWebSocketOutbound]
  subscribed_channels : Map[String, Unit]
}

///|
priv struct NativeWebSocketHub {
  connection_counter : Ref[Int]
  connections : Map[String, NativeWebSocketConnection]
  channels : Map[String, Map[String, Unit]]
}

///|
priv enum NativeWebSocketOutbound {
  SendText(String)
  SendBinary(Bytes)
}

///|
let native_ws_hubs : Map[String, NativeWebSocketHub] = Map::new()

///|
let native_ws_connection_hubs : Map[String, String] = Map::new()

///|
const NATIVE_WS_OUTGOING_QUEUE_CAPACITY : Int = 256

///|
fn ensure_native_ws_hub(runtime_id : String) -> NativeWebSocketHub {
  match native_ws_hubs.get(runtime_id) {
    Some(hub) => hub
    None => {
      let hub : NativeWebSocketHub = {
        connection_counter: Ref::new(0),
        connections: Map::new(),
        channels: Map::new(),
      }
      native_ws_hubs.set(runtime_id, hub)
      hub
    }
  }
}

///|
fn resolve_native_ws_connection(
  connection_id : String,
) -> (NativeWebSocketHub, NativeWebSocketConnection)? {
  match native_ws_connection_hubs.get(connection_id) {
    Some(runtime_id) =>
      match native_ws_hubs.get(runtime_id) {
        Some(hub) =>
          match hub.connections.get(connection_id) {
            Some(connection) => Some((hub, connection))
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn next_native_ws_connection_id(
  runtime_id : String,
  hub : NativeWebSocketHub,
) -> String {
  hub.connection_counter.val += 1
  "\{runtime_id}:\{hub.connection_counter.val}"
}

///|
fn snapshot_native_ws_channels(connection_id : String) -> Array[String] {
  match resolve_native_ws_connection(connection_id) {
    Some((_, connection)) => {
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
  runtime_id : String,
  connection_id : String,
  outgoing : @async.Queue[NativeWebSocketOutbound],
) -> Unit {
  let hub = ensure_native_ws_hub(runtime_id)
  hub.connections.set(connection_id, {
    outgoing,
    subscribed_channels: Map::new(),
  })
  native_ws_connection_hubs.set(connection_id, runtime_id)
}

///|
fn remove_native_ws_channel_member(
  hub : NativeWebSocketHub,
  channel : String,
  connection_id : String,
) -> Unit {
  match hub.channels.get(channel) {
    Some(members) => {
      if members.get(connection_id) is Some(_) {
        ignore(members.remove(connection_id))
      }
      if members.is_empty() {
        ignore(hub.channels.remove(channel))
      }
    }
    None => ()
  }
}

///|
fn unregister_native_ws_connection(connection_id : String) -> Unit {
  match native_ws_connection_hubs.get(connection_id) {
    Some(runtime_id) =>
      match native_ws_hubs.get(runtime_id) {
        Some(hub) =>
          match hub.connections.get(connection_id) {
            Some(connection) => {
              let channels = snapshot_native_ws_channels(connection_id)
              for channel in channels {
                remove_native_ws_channel_member(hub, channel, connection_id)
              }
              connection.outgoing.close()
              ignore(hub.connections.remove(connection_id))
              ignore(native_ws_connection_hubs.remove(connection_id))
              if hub.connections.is_empty() && hub.channels.is_empty() {
                ignore(native_ws_hubs.remove(runtime_id))
              }
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn enqueue_native_ws_outgoing(
  connection_id : String,
  message : NativeWebSocketOutbound,
) -> Unit {
  match resolve_native_ws_connection(connection_id) {
    Some((_, connection)) => ignore(try? connection.outgoing.try_put(message))
    None => ()
  }
}

///|
fn ws_send(id : String, msg : String) -> Unit {
  enqueue_native_ws_outgoing(id, SendText(msg))
}

///|
fn ws_send_bytes(id : String, msg : Bytes) -> Unit {
  enqueue_native_ws_outgoing(id, SendBinary(msg))
}

///|
fn ws_subscribe(id : String, channel : String) -> Unit {
  match resolve_native_ws_connection(id) {
    Some((hub, connection)) => {
      if connection.subscribed_channels.get(channel) is Some(_) {
        return
      }
      connection.subscribed_channels.set(channel, ())
      match hub.channels.get(channel) {
        Some(members) => members.set(id, ())
        None => {
          let members : Map[String, Unit] = Map::new()
          members.set(id, ())
          hub.channels.set(channel, members)
        }
      }
    }
    None => ()
  }
}

///|
fn ws_unsubscribe(id : String, channel : String) -> Unit {
  match resolve_native_ws_connection(id) {
    Some((hub, connection)) => {
      if connection.subscribed_channels.get(channel) is Some(_) {
        ignore(connection.subscribed_channels.remove(channel))
      }
      remove_native_ws_channel_member(hub, channel, id)
    }
    None => ()
  }
}

///|
fn ws_publish(connection_id : String, channel : String, msg : String) -> Unit {
  match resolve_native_ws_connection(connection_id) {
    Some((hub, _)) =>
      match hub.channels.get(channel) {
        Some(members) => {
          let connection_ids : Array[String] = []
          members.each((member_id, _) => connection_ids.push(member_id))
          for member_id in connection_ids {
            ws_send(member_id, msg)
          }
        }
        None => ()
      }
    None => ()
  }
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
  runtime_id : String,
  request : @http.Request,
  conn : @http.ServerConnection,
  handler : WebSocketHandler,
) -> Unit raise Error {
  let ws = @websocket.from_http_server(request, conn)
  defer ws.close()
  let hub = ensure_native_ws_hub(runtime_id)
  let connection_id = next_native_ws_connection_id(runtime_id, hub)
  let outgoing = @async.Queue::new(
    kind=DiscardOldest(NATIVE_WS_OUTGOING_QUEUE_CAPACITY),
  )
  register_native_ws_connection(runtime_id, connection_id, outgoing)
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

///|
fn cleanup_native_ws_runtime(runtime_id : String) -> Unit {
  match native_ws_hubs.get(runtime_id) {
    Some(hub) => {
      let connection_ids : Array[String] = []
      hub.connections.each((connection_id, _) => {
        connection_ids.push(connection_id)
      })
      for connection_id in connection_ids {
        unregister_native_ws_connection(connection_id)
      }
      ignore(native_ws_hubs.remove(runtime_id))
    }
    None => ()
  }
}
