///|
#external
priv type HttpServerInternal

///|
#external
priv type HttpRequestInternal

///|
#external
priv type HttpResponseInternal

///|
#borrow(self)
extern "c" fn HttpRequestInternal::req_method(
  self : HttpRequestInternal,
) -> Bytes = "req_method"

///|
#borrow(self)
extern "c" fn HttpRequestInternal::url(self : HttpRequestInternal) -> Bytes = "req_url"

///|
#borrow(self)
extern "c" fn HttpRequestInternal::headers(self : HttpRequestInternal) -> Bytes = "req_headers"

///|
#borrow(self)
extern "c" fn HttpRequestInternal::body(self : HttpRequestInternal) -> Bytes = "req_body"

///|
#borrow(self)
extern "c" fn HttpRequestInternal::req_body_len(
  self : HttpRequestInternal,
) -> Int = "req_body_len"

///|
#borrow(self, key, value)
extern "c" fn HttpResponseInternal::set_header(
  self : HttpResponseInternal,
  key : Bytes,
  value : Bytes,
) -> Unit = "res_set_header"

///|
#borrow(self, body)
extern "c" fn HttpResponseInternal::end_bytes(
  self : HttpResponseInternal,
  body : Bytes,
  body_len : Int,
) -> Unit = "res_end_bytes"

///|
#borrow(self)
extern "c" fn HttpResponseInternal::status(
  self : HttpResponseInternal,
  status_code : Int,
) -> Unit = "res_status"

///|
#borrow(server, address)
extern "c" fn server_listen_address(
  server : HttpServerInternal,
  address : Bytes,
  port : Int,
) -> Unit = "server_listen_address"

///|
#owned(handler)
extern "c" fn create_server(
  handler : FuncRef[(Int, HttpRequestInternal, HttpResponseInternal) -> Unit],
) -> HttpServerInternal = "create_server"

///|
#owned(cb)
extern "c" fn set_ws_emit(cb : FuncRef[(Bytes, Bytes, Bytes) -> Unit]) -> Unit = "set_ws_emit"

///|
#borrow(id, msg)
extern "c" fn ws_send_native(id : Bytes, msg : Bytes) -> Unit = "ws_send"

///|
#borrow(id, msg)
extern "c" fn ws_send_bytes_len_native(
  id : Bytes,
  msg : Bytes,
  len : Int,
) -> Unit = "ws_send_bytes_len"

///|
#borrow(id)
extern "c" fn ws_pong_native(id : Bytes) -> Unit = "ws_pong"

///|
extern "c" fn ws_msg_body_len() -> Int = "ws_msg_body_len"

///|
#borrow(dst)
extern "c" fn ws_msg_copy(dst : Bytes, max_len : Int) -> Int = "ws_msg_copy"

///|
let server_map : Map[Int, @mocket.Mocket] = {}

///|
let ws_handler_map : Map[Int, @mocket.WebSocketHandler] = {}

///|
fn[T : Show] to_cbytes(s : T) -> Bytes {
  @utf8.encode(s.to_string())
}

///|
fn from_cbytes(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}

///|
fn parse_headers(headers_text : String) -> Map[StringView, StringView] {
  let headers : Map[StringView, StringView] = {}
  headers_text
  .split("\n")
  .each(line => {
    let line = line.trim()
    if line != "" {
      if line.find(":") is Some(idx) {
        let key = line[:idx].trim()
        let value = line[idx + 1:].trim()
        if key != "" {
          headers.set(key, value)
        }
      }
    }
  })
  headers
}

///|
fn safe_request_body(req : HttpRequestInternal) -> Bytes {
  let req_body_len = req.req_body_len()
  let req_body = req.body()
  let safe_body_len = if req_body_len < 0 {
    0
  } else if req_body_len > req_body.length() {
    req_body.length()
  } else {
    req_body_len
  }
  req_body[0:safe_body_len].to_owned()
}

///|
fn first_ws_handler() -> @mocket.WebSocketHandler {
  match ws_handler_map.values().collect() {
    [handler, ..] => handler
    [] => fn(_) {  }
  }
}

///|
fn register_ws_handlers(mocket : @mocket.Mocket, port : Int) -> Unit {
  let mut done = false
  mocket.ws_static_routes.each(fn(_, handler) {
    if !done {
      ws_handler_map.set(port, handler)
      done = true
    }
  })
}

///|
fn handle_request(
  port : Int,
  req : HttpRequestInternal,
  res : HttpResponseInternal,
) -> Unit {
  let mocket = server_map[port]
  let url = from_cbytes(req.url())
  let http_method = from_cbytes(req.req_method())
  let headers = parse_headers(from_cbytes(req.headers()))
  let raw_body = safe_request_body(req)
  @mocket.async_run(async fn() noraise {
    let response = @mocket.dispatch_http(
      mocket, http_method, url, headers, raw_body,
    )
    res.status(response.status_code.to_int())
    response.headers.each((key, value) => {
      res.set_header(to_cbytes(key), to_cbytes(value))
    })
    response.cookies
    .values()
    .each(cookie => {
      res.set_header(to_cbytes("Set-Cookie"), to_cbytes(cookie.to_string()))
    })
    res.end_bytes(response.raw_body, response.raw_body.length())
  })
}

///|
#deprecated("use `listen(mocket, address)` instead")
pub fn serve(mocket : @mocket.Mocket, port~ : Int) -> Unit {
  listen(mocket, "0.0.0.0:\{port}")
}

///|
pub fn listen(mocket : @mocket.Mocket, address : String) -> Unit {
  let address = normalize_listen_address(address)
  let port = listen_port(address)
  server_map.set(port, mocket)
  register_ws_handlers(mocket, port)
  set_ws_emit(fn(event_type : Bytes, id : Bytes, payload : Bytes) {
    __ws_emit(event_type, id, payload)
  })
  let server = create_server(fn(
    port : Int,
    req : HttpRequestInternal,
    res : HttpResponseInternal,
  ) {
    handle_request(port, req, res)
  })
  server_listen_address(server, to_cbytes(address), port)
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
fn listen_port(address : String) -> Int {
  match address.rev_split_once(":") {
    Some((_, port_text)) => @string.parse_int(port_text) catch { _ => 0 }
    None => @string.parse_int(address) catch { _ => 0 }
  }
}

///|
pub fn __ws_emit(
  event_type : Bytes,
  connection_id : Bytes,
  payload : Bytes,
) -> Unit {
  let et = from_cbytes(event_type)
  let cid = from_cbytes(connection_id)
  let handler = first_ws_handler()
  let peer = @mocket.WebSocketPeer::{
    connection_id: cid,
    subscribed_channels: [],
  }
  match et {
    "open" => {
      @mocket.register_ws_connection(
        cid,
        msg => ws_send_native(to_cbytes(cid), to_cbytes(msg)),
        msg => ws_send_bytes_len_native(to_cbytes(cid), msg, msg.length()),
        () => ws_pong_native(to_cbytes(cid)),
      )
      handler(Open(peer))
    }
    "message" => handler(Message(peer, Text(from_cbytes(payload))))
    "binary" => {
      let len = ws_msg_body_len()
      let arr = Array::make(len, b'\x00')
      let buf = Bytes::from_array(arr)
      let copied = ws_msg_copy(buf, buf.length())
      let body = buf[0:copied].to_owned()
      handler(Message(peer, Binary(body)))
    }
    "ping" => handler(Message(peer, Ping))
    "close" => {
      @mocket.unregister_ws_connection(cid)
      handler(Close(peer))
    }
    _ => ()
  }
}
