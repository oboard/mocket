///|
type WsTextSender = (String) -> Unit

///|
type WsBinarySender = (Bytes) -> Unit

///|
type WsPongSender = () -> Unit

///|
let ws_text_senders : Map[String, WsTextSender] = {}

///|
let ws_binary_senders : Map[String, WsBinarySender] = {}

///|
let ws_pong_senders : Map[String, WsPongSender] = {}

///|
let ws_client_channels : Map[String, Array[String]] = {}

///|
let ws_channel_clients : Map[String, Map[String, Unit]] = {}

///|
let native_ws_handler_map : Map[Int, Mocket] = {}

///|
fn request_method_to_string(meth : @http.RequestMethod) -> String {
  match meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
fn string_headers_to_views(
  headers : Map[String, String],
) -> Map[StringView, StringView] {
  let out : Map[StringView, StringView] = {}
  headers.each((key, value) => out.set(key, value))
  out
}

///|
fn view_headers_to_strings(
  headers : Map[StringView, StringView],
) -> Map[String, String] {
  let out : Map[String, String] = {}
  headers.each((key, value) => out.set(key.to_string(), value.to_string()))
  out
}

///|
fn header_contains_token(
  headers : Map[String, String],
  header_name : String,
  token : String,
) -> Bool {
  let token = token.to_lower()
  let header_name = header_name.to_lower()
  for pair in headers {
    let (key, value) = pair
    if key.to_lower() == header_name {
      for part in value.split(",") {
        if part.trim().to_lower() == token {
          return true
        }
      }
    }
  }
  false
}

///|
fn header_equals(
  headers : Map[String, String],
  header_name : String,
  expected : String,
) -> Bool {
  let header_name = header_name.to_lower()
  let expected = expected.to_lower()
  for pair in headers {
    let (key, value) = pair
    if key.to_lower() == header_name {
      return value.trim().to_lower() == expected
    }
  }
  false
}

///|
fn is_websocket_upgrade(request : @http.Request) -> Bool {
  header_contains_token(request.headers, "connection", "upgrade") &&
  header_equals(request.headers, "upgrade", "websocket")
}

///|
fn find_ws_route(
  mocket : Mocket,
  path : String,
) -> (WebSocketHandler, Map[String, StringView])? {
  match mocket.ws_static_routes.get(path) {
    Some(handler) => return Some((handler, {}))
    None => ()
  }
  for route in mocket.ws_dynamic_routes {
    let (route_path, handler) = route
    match match_path(route_path, path) {
      Some(params) => return Some((handler, params))
      None => ()
    }
  }
  None
}

///|
fn next_ws_connection_id(port : Int) -> String {
  "native-\{port}-\{@async.now()}"
}

///|
pub fn register_ws_connection(
  connection_id : String,
  text_sender : WsTextSender,
  binary_sender : WsBinarySender,
  pong_sender : WsPongSender,
) -> Unit {
  ws_text_senders.set(connection_id, text_sender)
  ws_binary_senders.set(connection_id, binary_sender)
  ws_pong_senders.set(connection_id, pong_sender)
  ws_client_channels.set(connection_id, [])
}

///|
pub fn unregister_ws_connection(connection_id : String) -> Unit {
  let channels = ws_client_channels.get(connection_id)
  ignore(ws_text_senders.remove(connection_id))
  ignore(ws_binary_senders.remove(connection_id))
  ignore(ws_pong_senders.remove(connection_id))
  ignore(ws_client_channels.remove(connection_id))
  match channels {
    Some(channels) =>
      for channel in channels {
        match ws_channel_clients.get(channel) {
          Some(clients) => ignore(clients.remove(connection_id))
          None => ()
        }
      }
    None => ()
  }
}

///|
pub fn register_ws_handler(mocket : Mocket, port : Int) -> Unit {
  native_ws_handler_map.set(port, mocket)
}

///|
pub fn ws_send(id : String, msg : String) -> Unit {
  match ws_text_senders.get(id) {
    Some(send) => send(msg)
    None => ()
  }
}

///|
pub fn ws_send_bytes(id : String, msg : Bytes) -> Unit {
  match ws_binary_senders.get(id) {
    Some(send) => send(msg)
    None => ()
  }
}

///|
pub fn ws_pong(id : String) -> Unit {
  match ws_pong_senders.get(id) {
    Some(send) => send()
    None => ()
  }
}

///|
pub fn ws_subscribe(id : String, channel : String) -> Unit {
  let client_channels = match ws_client_channels.get(id) {
    Some(channels) => channels
    None => {
      let channels = []
      ws_client_channels.set(id, channels)
      channels
    }
  }
  if !client_channels.contains(channel) {
    client_channels.push(channel)
  }
  let channel_clients = match ws_channel_clients.get(channel) {
    Some(clients) => clients
    None => {
      let clients : Map[String, Unit] = {}
      ws_channel_clients.set(channel, clients)
      clients
    }
  }
  channel_clients.set(id, ())
}

///|
pub fn ws_unsubscribe(id : String, channel : String) -> Unit {
  match ws_channel_clients.get(channel) {
    Some(clients) => ignore(clients.remove(id))
    None => ()
  }
  match ws_client_channels.get(id) {
    Some(channels) => {
      let mut index = None
      for i = 0; i < channels.length(); i = i + 1 {
        if channels[i] == channel {
          index = Some(i)
          break
        }
      }
      match index {
        Some(i) => ignore(channels.remove(i))
        None => ()
      }
    }
    None => ()
  }
}

///|
pub fn ws_publish(channel : String, msg : String) -> Unit {
  match ws_channel_clients.get(channel) {
    Some(clients) => clients.keys().each(id => ws_send(id, msg))
    None => ()
  }
}

///|
async fn send_native_response(
  request : @http.Request,
  conn : @http.ServerConnection,
  response : HttpResponse,
) -> Unit {
  let headers = view_headers_to_strings(response.headers)
  if !response.cookies.is_empty() {
    let cookies = response.cookies
      .values()
      .map(cookie => cookie.to_string())
      .to_array()
    headers.set("Set-Cookie", cookies.join("\r\nSet-Cookie: "))
  }
  conn.send_response(response.status_code.to_int(), "OK", extra_headers=headers)
  if request.meth != Head && !response.raw_body.is_empty() {
    conn.write(response.raw_body)
  }
  conn.end_response()
}

///|
async fn handle_http_request(
  mocket : Mocket,
  request : @http.Request,
  body_reader : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let raw_body = body_reader.read_all().binary()
  let response = dispatch_http(
    mocket,
    request_method_to_string(request.meth),
    request.path,
    string_headers_to_views(request.headers),
    raw_body,
  )
  send_native_response(request, conn, response)
}

///|
async fn handle_websocket_request(
  port : Int,
  mocket : Mocket,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  match find_ws_route(mocket, request.path) {
    Some((handler, _params)) => {
      let ws = @websocket.from_http_server(request, conn)
      defer ws.close()
      let connection_id = next_ws_connection_id(port)
      let peer = WebSocketPeer::{ connection_id, subscribed_channels: [] }
      register_ws_connection(
        connection_id,
        msg => {
          async_run(async fn() noraise { ws.send_text(msg) catch { _ => () } })
        },
        msg => {
          async_run(async fn() noraise { ws.send_binary(msg) catch { _ => () } })
        },
        () => async_run(async fn() noraise { ws.ping() catch { _ => () } }),
      )
      handler(Open(peer))
      try {
        for ;; {
          let msg = ws.recv()
          match msg.kind {
            Text => {
              let text = msg.read_all().text() catch { _ => "" }
              handler(Message(peer, Text(text)))
            }
            Binary => handler(Message(peer, Binary(msg.read_all().binary())))
          }
        }
      } catch {
        @websocket.ConnectionClosed(_, _) => ()
        _ => ()
      }
      handler(Close(peer))
      unregister_ws_connection(connection_id)
    }
    None => {
      let response = HttpResponse::new(NotFound, raw_body=b"Not Found")
      response.headers.set("Content-Type", "text/plain; charset=utf-8")
      send_native_response(request, conn, response)
    }
  }
}

///|
pub async fn listen_ffi(mocket : Mocket, address : String) -> Unit noraise {
  let address = normalize_listen_address(address)
  let addr = @socket.Addr::parse(address) catch {
    err => {
      println("mocket: invalid native listen address \{address}: \{err}")
      return
    }
  }
  let port = addr.port()
  register_ws_handler(mocket, port)
  let server = @http.Server(addr) catch {
    err => {
      println("mocket: failed to listen on \{address}: \{err}")
      return
    }
  }
  server.run_forever((request, body_reader, conn) => {
    if is_websocket_upgrade(request) {
      handle_websocket_request(port, mocket, request, conn)
    } else {
      handle_http_request(mocket, request, body_reader, conn)
    }
  }) catch {
    err => println("mocket: native server on \{address} stopped: \{err}")
  }
}

///|
fn normalize_listen_address(address : String) -> String {
  if address.has_prefix(":") {
    "0.0.0.0\{address}"
  } else {
    address
  }
}

///|
pub async fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit noraise {
  listen_ffi(mocket, "127.0.0.1:\{port}")
}

///|
pub fn __ws_emit(
  event_type : Bytes,
  connection_id : Bytes,
  payload : Bytes,
) -> Unit {
  let peer = WebSocketPeer::{
    connection_id: @utf8.decode_lossy(connection_id),
    subscribed_channels: [],
  }
  let handler = match native_ws_handler_map.values().collect() {
    [mocket, ..] =>
      match mocket.ws_static_routes.values().collect() {
        [handler, ..] => handler
        [] => fn(_) {  }
      }
    [] => fn(_) {  }
  }
  match @utf8.decode_lossy(event_type) {
    "open" => handler(Open(peer))
    "message" => handler(Message(peer, Text(@utf8.decode_lossy(payload))))
    "binary" => handler(Message(peer, Binary(payload)))
    "ping" => handler(Message(peer, Ping))
    "close" => handler(Close(peer))
    _ => ()
  }
}
