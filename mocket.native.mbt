///|
#external
pub type HttpServerInternal

///|
#external
pub type HttpRequestInternal

///|
#external
pub type HttpResponseInternal

///|
extern "c" fn HttpRequestInternal::req_method(
  self : HttpRequestInternal,
) -> Bytes = "req_method"

///|
extern "c" fn HttpRequestInternal::url(self : HttpRequestInternal) -> Bytes = "req_url"

///|
extern "c" fn HttpRequestInternal::headers(self : HttpRequestInternal) -> Bytes = "req_headers"

///|
#owned(self, key, value)
extern "c" fn HttpResponseInternal::set_header(
  self : HttpResponseInternal,
  key : Bytes,
  value : Bytes,
) -> Unit = "res_set_header"

///|
#owned(self, cb)
pub extern "c" fn HttpRequestInternal::on_headers(
  self : HttpRequestInternal,
  cb : FuncRef[(Bytes) -> Unit],
) -> Unit = "req_on_headers"

///|
#owned(self, cb)
pub extern "c" fn HttpRequestInternal::on_complete(
  self : HttpRequestInternal,
  cb : FuncRef[() -> Unit],
) -> Unit = "req_on_complete"

///|
#owned(self)
extern "c" fn HttpRequestInternal::body(self : HttpRequestInternal) -> Bytes = "req_body"

///|
#owned(self)
extern "c" fn HttpRequestInternal::req_body_len(
  self : HttpRequestInternal,
) -> Int = "req_body_len"

// ///|
// #owned(self, body)
// extern "c" fn HttpResponseInternal::end(
//   self : HttpResponseInternal,
//   body : Bytes,
// ) -> Unit = "res_end"

///|
#owned(self, body)
extern "c" fn HttpResponseInternal::end_bytes(
  self : HttpResponseInternal,
  body : Bytes,
) -> Unit = "res_end_bytes"

///|
#owned(self, status_code)
extern "c" fn HttpResponseInternal::status(
  self : HttpResponseInternal,
  status_code : Int,
) -> Unit = "res_status"

///|
#owned(port)
extern "c" fn server_listen(server : HttpServerInternal, port : Int) -> Unit = "server_listen"

///|
#owned(handler)
extern "c" fn create_server(
  handler : FuncRef[(Int, HttpRequestInternal, HttpResponseInternal) -> Unit],
) -> HttpServerInternal = "create_server"

///|
#owned(cb)
extern "c" fn set_ws_emit(cb : FuncRef[(Bytes, Bytes, Bytes) -> Unit]) -> Unit = "set_ws_emit"

///|
let server_map : Map[Int, Mocket] = Map::new()

///|
let ws_handler_map : Map[Int, WebSocketHandler] = Map::new()

///|
pub fn register_ws_handler(mocket : Mocket, port : Int) -> Unit {
  let mut done = false
  mocket.ws_static_routes.each(fn(_, handler) {
    if !done {
      ws_handler_map.set(port, handler)
      done = true
    }
  })
}

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  server_map[port] = mocket
  register_ws_handler(mocket, port)
  set_ws_emit(fn(event_type : Bytes, id : Bytes, payload : Bytes) {
    __ws_emit(event_type, id, payload)
  })
  let server = create_server(fn(
    port : Int,
    req : HttpRequestInternal,
    res : HttpResponseInternal,
  ) {
    handle_request_native(port, req, res)
  })
  server_listen(server, port)
}

///|
fn handle_request_native(
  port : Int,
  req : HttpRequestInternal,
  res : HttpResponseInternal,
) -> Unit {
  let mocket = server_map[port]
  // 直接使用 C FFI 获取请求数据
  let url = from_cbytes(req.url())
  let path = url
  let http_method = from_cbytes(req.req_method())

  // // 创建 HttpRequest
  // let http_req : HttpRequest = {
  //   http_method: http_method,
  //   url,
  //   body,
  //   headers: Map::new(),
  // }
  // let http_res = { status_code: 200, headers: Map::new() }

  // // 创建 HttpEvent
  // let event : HttpEvent = { req: http_req, res: http_res, params: Map::new() }

  // // 简单响应
  // res.set_header(to_cbytes("Content-Type"), to_cbytes("application/json"))
  // res.status(200)
  // res.end(to_cbytes("{\"status\":\"ok\"}"))

  let headers_str = from_cbytes(req.headers())
  let req_headers = Map::new()
  headers_str
  .split("\n")
  .each(fn(line) {
    let line = line.trim()
    if line == "" {
      return
    }

    if line.find(":") is Some(idx) {
      let key = line[0:idx].trim()
      let value = line[idx + 1:].trim()
      if key != "" {
        req_headers.set(key, value)
      }
    }
  })
  let (params, handler) = match mocket.find_route(http_method, path) {
    Some((h, p)) => (p, h)
    _ => ({}, handle_not_found())
  }
  let event = {
    req: { http_method, url, raw_body: b"", headers: req_headers },
    res: HttpResponse::new(OK),
    params,
  }
  if http_method == "POST" {
    let req_body_len = req.req_body_len()
    let req_body = req.body()
    let safe_body_len = if req_body_len < 0 {
      0
    } else if req_body_len > req_body.length() {
      req_body.length()
    } else {
      req_body_len
    }
    let body_bytes = req_body[0:safe_body_len]
    event.req.raw_body = body_bytes.to_bytes()
  }
  async_run(async fn() noraise {
    // 执行中间件链和处理器
    let responder = execute_middlewares(mocket.middlewares, event, handler)
    responder.options(event.res)
    res.status(event.res.status_code.to_int())
    event.res.headers.each((key, value) => {
      res.set_header(to_cbytes(key), to_cbytes(value))
    })
    event.res.cookies
    .values()
    .each(cookie => {
      res.set_header(to_cbytes("Set-Cookie"), to_cbytes(cookie.to_string()))
    })
    let buf = @buffer.new()
    responder.output(buf)
    event.res.raw_body = buf.to_bytes()
    res.end_bytes(event.res.raw_body)
  })
}

///|
pub fn __ws_emit(
  event_type : Bytes,
  connection_id : Bytes,
  payload : Bytes,
) -> Unit {
  let et = from_cbytes(event_type)
  let cid = from_cbytes(connection_id)
  let handler = if ws_handler_map.is_empty() {
    fn(_) {  }
  } else {
    ws_handler_map.get(ws_handler_map.keys().collect()[0]).unwrap()
  }
  let peer = WebSocketPeer::{ connection_id: cid, subscribed_channels: [] }
  match et {
    "open" => handler(WebSocketEvent::Open(peer))
    "message" => {
      let pl = from_cbytes(payload)
      handler(WebSocketEvent::Message(peer, Text(pl)))
    }
    "binary" => {
      let len = ws_msg_body_len()
      let arr = Array::make(len, b'\x00')
      let buf = Bytes::from_array(arr)
      let copied = ws_msg_copy(buf)
      let body = buf[0:copied].to_bytes()
      handler(WebSocketEvent::Message(peer, Binary(body)))
    }
    "ping" => handler(WebSocketEvent::Message(peer, Ping))
    "close" => handler(WebSocketEvent::Close(peer))
    _ => ()
  }
}

///|
#owned(id, msg)
extern "c" fn ws_send_native(id : Bytes, msg : Bytes) -> Unit = "ws_send"

///|
#owned(id, channel)
extern "c" fn ws_subscribe_native(id : Bytes, channel : Bytes) -> Unit = "ws_subscribe"

///|
#owned(id, channel)
extern "c" fn ws_unsubscribe_native(id : Bytes, channel : Bytes) -> Unit = "ws_unsubscribe"

///|
#owned(channel, msg)
extern "c" fn ws_publish_native(channel : Bytes, msg : Bytes) -> Unit = "ws_publish"

///|
#owned(id, msg)
extern "c" fn ws_send_bytes_len_native(
  id : Bytes,
  msg : Bytes,
  len : Int,
) -> Unit = "ws_send_bytes_len"

///|
#owned(id)
extern "c" fn ws_pong_native(id : Bytes) -> Unit = "ws_pong"

///|
// extern "c" fn ws_msg_body() -> Bytes = "ws_msg_body"

///|
extern "c" fn ws_msg_body_len() -> Int = "ws_msg_body_len"

///|
#owned(dst)
extern "c" fn ws_msg_copy(dst : Bytes) -> Int = "ws_msg_copy"

///|
pub fn ws_send(id : String, msg : String) -> Unit {
  ws_send_native(to_cbytes(id), to_cbytes(msg))
}

///|
pub fn ws_send_bytes(id : String, msg : Bytes) -> Unit {
  ws_send_bytes_len_native(to_cbytes(id), msg, msg.length())
}

///|
pub fn ws_pong(id : String) -> Unit {
  ws_pong_native(to_cbytes(id))
}

///|
pub fn ws_subscribe(id : String, channel : String) -> Unit {
  ws_subscribe_native(to_cbytes(id), to_cbytes(channel))
}

///|
pub fn ws_unsubscribe(id : String, channel : String) -> Unit {
  ws_unsubscribe_native(to_cbytes(id), to_cbytes(channel))
}

///|
pub fn ws_publish(channel : String, msg : String) -> Unit {
  ws_publish_native(to_cbytes(channel), to_cbytes(msg))
}

///|
fn[T : Show] to_cbytes(s : T) -> Bytes {
  @utf8.encode(s.to_string())
}

///|
fn from_cbytes(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}
