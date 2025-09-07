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
let server_map : Map[Int, Mocket] = Map::new()

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  server_map[port] = mocket
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
  run(() => {
    // 执行中间件链
    execute_middlewares(mocket.middlewares, event)
    let body = handler(event)
    if not(body is Empty) {
      event.res.headers.set(
        "Content-Type",
        match body {
          Bytes(_) => "application/octet-stream"
          HTML(_) => "text/html; charset=utf-8"
          Text(_) => "text/plain; charset=utf-8"
          Json(_) => "application/json; charset=utf-8"
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
          _ => to_cstr("")
        },
      )
    }
  })
}

///|
fn[T : Show] to_cstr(s : T) -> @native.CStr {
  let bytes = @encoding.encode(UTF8, s.to_string())
  let utf8_ptr = @native.unsafe_coerce(bytes)
  utf8_ptr
}

///|
fn from_cstr(cstr : @native.CStr) -> String {
  let bytes = cstr.to_bytes()[:-1]
  let utf8 = @encoding.decoder(UTF8).decode(bytes) catch { _ => panic() }
  utf8
}
