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
) -> @native.CStr = "req_method"

///|
extern "c" fn HttpRequestInternal::url(
  self : HttpRequestInternal,
) -> @native.CStr = "req_url"

///|
extern "c" fn HttpRequestInternal::headers(
  self : HttpRequestInternal,
) -> @native.CStr = "req_headers"

///|
#owned(self, key, value)
extern "c" fn HttpResponseInternal::set_header(
  self : HttpResponseInternal,
  key : @native.CStr,
  value : @native.CStr,
) -> Unit = "res_set_header"

///|
#owned(self, cb)
pub extern "c" fn HttpRequestInternal::on_headers(
  self : HttpRequestInternal,
  cb : FuncRef[(@native.CStr) -> Unit],
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

///|
#owned(self, body)
extern "c" fn HttpResponseInternal::end(
  self : HttpResponseInternal,
  body : @native.CStr,
) -> Unit = "res_end"

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
extern "c" fn set_ws_emit(
  cb : FuncRef[(@native.CStr, @native.CStr, @native.CStr) -> Unit],
) -> Unit = "set_ws_emit"

///|
let server_map : Map[Int, Mocket] = Map::new()

///|
let ws_handler_map : Map[Int, WebSocketHandler] = Map::new()

///|
pub fn register_ws_handler(mocket : Mocket, port : Int) -> Unit {
  let mut done = false
  mocket.ws_static_routes.each(fn(_, handler) {
    if not(done) {
      ws_handler_map.set(port, handler)
      done = true
    }
  })
}

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  server_map[port] = mocket
  register_ws_handler(mocket, port)
  set_ws_emit(fn(
    event_type : @native.CStr,
    id : @native.CStr,
    payload : @native.CStr,
  ) {
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
  let url = from_cstr(req.url())
  let path = url
  let http_method = from_cstr(req.req_method())

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
  // res.set_header(to_cstr("Content-Type"), to_cstr("application/json"))
  // res.status(200)
  // res.end(to_cstr("{\"status\":\"ok\"}"))

  let headers_str = from_cstr(req.headers())
  let req_headers = headers_str
    .split("\n")
    .map(fn(pair) {
      if pair.length() > 0 && pair.split(": ").to_array() is [key, value] {
        (key.to_string(), value.to_string())
      } else {
        ("", "")
      }
    })
    .filter(fn(pair) { pair.0.length() > 0 })
    .to_array()
    |> Map::from_array
  let (params, handler) = match mocket.find_route(http_method, path) {
    Some((h, p)) => (p, h)
    _ => {
      res.status(404)
      res.end(to_cstr("Not Found"))
      return
    }
  }
  let event = {
    req: { http_method, url, body: Empty, headers: req_headers },
    res: { status_code: 200, headers: {} },
    params,
  }
  if http_method == "POST" {
    let req_body_len = req.req_body_len()
    let body_bytes = req.body()[0:req_body_len]
    let body = read_body(req_headers, body_bytes) catch {
      _ => {
        res.status(400)
        res.end(to_cstr("Invalid body"))
        return
      }
    }
    event.req.body = body
  }
  async_run(async fn() noraise {
    // 执行中间件链和处理器
    let body = execute_middlewares(mocket.middlewares, event, handler)
    if not(body is Empty) {
      event.res.headers.set(
        "Content-Type",
        match body {
          Bytes(_) => "application/octet-stream"
          HTML(_) => "text/html; charset=utf-8"
          Text(_) => "text/plain; charset=utf-8"
          Json(_) => "application/json; charset=utf-8"
          Form(_) => "application/x-www-form-urlencoded"
          Multipart(_) => "multipart/form-data"
          Empty => ""
        },
      )
    }
    res.status(event.res.status_code)
    event.res.headers.each(fn(key, value) {
      res.set_header(to_cstr(key), to_cstr(value))
    })
    if body is Bytes(bytes) {
      res.end_bytes(bytes.to_bytes())
    } else {
      res.end(
        match body {
          HTML(s) => to_cstr(s.to_string())
          Text(s) => to_cstr(s.to_string())
          Json(j) => to_cstr(j.stringify())
          Form(m) => to_cstr(form_encode(m))
          Multipart(_) => to_cstr("")
          _ => to_cstr("")
        },
      )
    }
  })
}

///|
pub fn __ws_emit(
  event_type : @native.CStr,
  connection_id : @native.CStr,
  payload : @native.CStr,
) -> Unit {
  let et = from_cstr(event_type)
  let cid = from_cstr(connection_id)
  let pl = from_cstr(payload)
  let handler = if ws_handler_map.is_empty() {
    fn(_) {  }
  } else {
    ws_handler_map.get(ws_handler_map.keys().collect()[0]).unwrap()
  }
  let peer = WebSocketPeer::{ connection_id: cid, subscribed_channels: [] }
  match et {
    "open" => handler(WebSocketEvent::Open(peer))
    "message" => handler(WebSocketEvent::Message(peer, Text(pl)))
    "close" => handler(WebSocketEvent::Close(peer))
    _ => ()
  }
}

///|
#owned(id, msg)
extern "c" fn ws_send_native(id : @native.CStr, msg : @native.CStr) -> Unit = "ws_send"

///|
#owned(id, channel)
extern "c" fn ws_subscribe_native(
  id : @native.CStr,
  channel : @native.CStr,
) -> Unit = "ws_subscribe"

///|
#owned(id, channel)
extern "c" fn ws_unsubscribe_native(
  id : @native.CStr,
  channel : @native.CStr,
) -> Unit = "ws_unsubscribe"

///|
#owned(channel, msg)
extern "c" fn ws_publish_native(
  channel : @native.CStr,
  msg : @native.CStr,
) -> Unit = "ws_publish"

///|
pub fn ws_send(id : String, msg : String) -> Unit {
  ws_send_native(to_cstr(id), to_cstr(msg))
}

///|
pub fn ws_subscribe(id : String, channel : String) -> Unit {
  ws_subscribe_native(to_cstr(id), to_cstr(channel))
}

///|
pub fn ws_unsubscribe(id : String, channel : String) -> Unit {
  ws_unsubscribe_native(to_cstr(id), to_cstr(channel))
}

///|
pub fn ws_publish(channel : String, msg : String) -> Unit {
  ws_publish_native(to_cstr(channel), to_cstr(msg))
}

///|
fn[T : Show] to_cstr(s : T) -> @native.CStr {
  let bytes = @encoding/utf8.encode(s.to_string())
  let utf8_ptr = @native.unsafe_coerce(bytes)
  utf8_ptr
}

///|
fn from_cstr(cstr : @native.CStr) -> String {
  let bytes = cstr.to_bytes()[:-1]
  let utf8 = @encoding/utf8.decode(bytes) catch { _ => panic() }
  utf8
}
