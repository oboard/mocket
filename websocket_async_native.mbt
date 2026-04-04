///|
priv struct NativeWebSocketConnection {
  outgoing : @async.Queue[NativeWebSocketOutbound]
  overflow_policy : NativeWebSocketOverflowPolicy
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
const DEFAULT_NATIVE_WS_OUTGOING_QUEUE_CAPACITY : Int = 256

///|
const NATIVE_WS_READ_TIMEOUT_REASON : String = "websocket read timeout"

///|
const NATIVE_WS_MESSAGE_TOO_BIG_REASON : String = "websocket message too big"

///|
const NATIVE_WS_SERVER_SHUTDOWN_REASON : String = "websocket server shutdown"

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
  overflow_policy : NativeWebSocketOverflowPolicy,
) -> Unit {
  let hub = ensure_native_ws_hub(runtime_id)
  hub.connections.set(connection_id, {
    outgoing,
    overflow_policy,
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
    Some((_, connection)) =>
      enqueue_native_ws_outgoing_to_connection(connection, message)
    None => ()
  }
}

///|
fn enqueue_native_ws_outgoing_to_connection(
  connection : NativeWebSocketConnection,
  message : NativeWebSocketOutbound,
) -> Unit {
  let enqueue_result : Result[Bool, Error] = try? connection.outgoing.try_put(
    message,
  )
  match enqueue_result {
    Ok(true) => ()
    Ok(false) =>
      match connection.overflow_policy {
        NativeWebSocketOverflowPolicy::DropOldest => {
          ignore(try? connection.outgoing.try_get())
          ignore(try? connection.outgoing.try_put(message))
        }
        NativeWebSocketOverflowPolicy::DropLatest => ()
      }
    Err(_) => ()
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
async fn recv_native_ws_message(
  ws : @websocket.Conn,
  read_timeout_ms : Int?,
) -> @websocket.Message? raise Error {
  match read_timeout_ms {
    Some(read_timeout_ms) =>
      match @async.with_timeout_opt(read_timeout_ms, () => try? ws.recv()) {
        Some(Ok(message)) => Some(message)
        Some(Err(@websocket.ConnectionClosed(_, _))) => None
        Some(Err(err)) => raise err
        None => {
          ignore(
            try? ws.send_close(
              code=@websocket.CloseCode::GoingAway,
              reason=NATIVE_WS_READ_TIMEOUT_REASON,
            ),
          )
          None
        }
      }
    None => {
      let message_result : Result[@websocket.Message, Error] = try? ws.recv()
      match message_result {
        Ok(message) => Some(message)
        Err(@websocket.ConnectionClosed(_, _)) => None
        Err(err) => raise err
      }
    }
  }
}

///|
fn decode_native_ws_message(
  message_kind : @websocket.MessageKind,
  contents : Bytes,
) -> WebSocketAggregatedMessage {
  match message_kind {
    Text =>
      Text(
        @utf8.decode(contents) catch {
          _ => abort("validated websocket text message must be valid UTF-8")
        },
      )
    Binary => Binary(contents)
  }
}

///|
fn next_native_ws_message_chunk_size(limit : Int, total : Int) -> Int {
  let remaining = limit - total
  if remaining >= 1024 {
    1024
  } else {
    remaining + 1
  }
}

///|
fn native_ws_chunk_exceeds_limit(
  limit : Int,
  total : Int,
  chunk_length : Int,
) -> Bool {
  chunk_length > limit - total
}

///|
async fn read_native_ws_message_contents(
  ws : @websocket.Conn,
  message : @websocket.Message,
  max_message_bytes : Int?,
) -> WebSocketAggregatedMessage? raise Error {
  match max_message_bytes {
    None =>
      Some(
        match message.kind {
          Text => Text(message.read_all().text())
          Binary => Binary(message.read_all().binary())
        },
      )
    Some(limit) => {
      let buffer = @buffer.new()
      let mut total = 0
      for ;; {
        let next_chunk_size = next_native_ws_message_chunk_size(limit, total)
        guard message.read_some(max_len=next_chunk_size) is Some(chunk) else {
          return Some(decode_native_ws_message(message.kind, buffer.contents()))
        }
        if native_ws_chunk_exceeds_limit(limit, total, chunk.length()) {
          ignore(
            try? ws.send_close(
              code=@websocket.CloseCode::MessageTooBig,
              reason=NATIVE_WS_MESSAGE_TOO_BIG_REASON,
            ),
          )
          return None
        }
        total += chunk.length()
        buffer.write_bytes(chunk)
      }
    }
  }
}

///|
async fn send_native_ws_shutdown_close(ws : @websocket.Conn) -> Unit {
  ignore(
    try? @async.protect_from_cancel(resume_on_cancel=true, () => {
      ws.send_close(
        code=@websocket.CloseCode::GoingAway,
        reason=NATIVE_WS_SERVER_SHUTDOWN_REASON,
      )
    }),
  )
}

///|
fn normalize_native_websocket_request_headers(
  headers : Map[String, String],
) -> Map[String, String] {
  let normalized : Map[String, String] = {}
  headers.each((key, value) => {
    let normalized_value = match key.to_lower() {
      "connection" =>
        value.split(",").map(token => token.trim()).to_array().join(", ")
      "upgrade" | "sec-websocket-version" | "sec-websocket-key" =>
        value.trim().to_string()
      _ => value
    }
    normalized.set(key, normalized_value)
  })
  normalized
}

///|
fn normalize_native_websocket_request(request : @http.Request) -> @http.Request {
  {
    meth: request.meth,
    path: request.path,
    headers: normalize_native_websocket_request_headers(request.headers),
  }
}

///|
async fn handle_websocket_route_async(
  runtime_id : String,
  request : @http.Request,
  conn : @http.ServerConnection,
  handler : WebSocketHandler,
  max_message_bytes : Int?,
  outgoing_queue_capacity : Int,
  overflow_policy : NativeWebSocketOverflowPolicy,
  read_timeout_ms : Int?,
) -> Unit raise Error {
  let ws = @websocket.from_http_server(
    normalize_native_websocket_request(request),
    conn,
  )
  defer ws.close()
  let hub = ensure_native_ws_hub(runtime_id)
  let connection_id = next_native_ws_connection_id(runtime_id, hub)
  let outgoing = @async.Queue::new(kind=Blocking(outgoing_queue_capacity))
  register_native_ws_connection(
    runtime_id, connection_id, outgoing, overflow_policy,
  )
  @async.with_task_group(group => {
    group.spawn_bg(() => write_native_ws_outgoing(ws, outgoing))
    handler(Open(snapshot_native_ws_peer(connection_id)))
    for ;; {
      let message = match recv_native_ws_message(ws, read_timeout_ms) {
        Some(message) => message
        None => break
      }
      let peer = snapshot_native_ws_peer(connection_id)
      match read_native_ws_message_contents(ws, message, max_message_bytes) {
        Some(aggregated_message) => handler(Message(peer, aggregated_message))
        None => break
      }
    }
    outgoing.close()
  }) catch {
    err => {
      if @async.is_cancellation_error(err) {
        send_native_ws_shutdown_close(ws)
      }
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
