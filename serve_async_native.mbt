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
fn copy_async_headers(headers : Map[String, String]) -> Map[String, String] {
  let copied : Map[String, String] = {}
  headers.each((key, value) => copied.set(key, value))
  copied
}

///|
fn response_headers_to_async(
  headers : Map[String, String],
) -> Map[String, String] {
  let copied : Map[String, String] = {}
  headers.each((key, value) => copied.set(key, value))
  copied
}

///|
let ws_serve_runtime_counter : Ref[Int] = Ref::new(0)

///|
fn next_ws_serve_runtime_id(app : Mocket) -> String {
  ws_serve_runtime_counter.val += 1
  "\{app.ws_runtime_id}/serve-\{ws_serve_runtime_counter.val}"
}

///|
fn append_cookie_headers(
  headers : Map[String, String],
  cookies : Map[String, CookieItem],
) -> Unit {
  if cookies.is_empty() {
    return
  }
  let cookie_lines = cookies
    .values()
    .map(cookie => cookie.to_string())
    .to_array()
  match cookie_lines {
    [] => ()
    [cookie] => headers.set("Set-Cookie", cookie)
    _ => headers.set("Set-Cookie", cookie_lines.join("\r\nSet-Cookie: "))
  }
}

///|
fn is_websocket_upgrade_request(request : @http.Request) -> Bool {
  match get_header_case_insensitive(request.headers, "upgrade") {
    Some(value) => value.to_lower() == "websocket"
    None => false
  }
}

///|
priv enum HttpRouteLookup {
  Found(HttpHandler, Map[String, StringView])
  MethodNotAllowed(String)
  Options(String)
  NotFound
}

///|
fn allow_header_value(methods : Array[String]) -> String {
  methods.join(", ")
}

///|
fn method_not_allowed_handler(allow : String) -> HttpHandler {
  fn(event) noraise {
    event.res.headers.set("Allow", allow)
    HttpResponse::new(MethodNotAllowed).body("Method Not Allowed")
  }
}

///|
fn options_handler(allow : String) -> HttpHandler {
  fn(event) noraise {
    event.res.headers.set("Allow", allow)
    HttpResponse::new(NoContent)
  }
}

///|
async fn send_raw_response_async(
  conn : @http.ServerConnection,
  response : HttpResponse,
  headers : Map[String, String],
  include_body : Bool,
) -> Unit raise Error {
  if !has_header_case_insensitive(headers, "Content-Length") {
    headers.set("Content-Length", response.raw_body.length().to_string())
  }
  if !has_header_case_insensitive(headers, "Connection") {
    headers.set("Connection", "close")
  }
  let raw_response = @buffer.new()
  raw_response.write_string_utf8("HTTP/1.1 ")
  raw_response.write_string_utf8(response.status_code.to_int().to_string())
  raw_response.write_string_utf8(" ")
  raw_response.write_string_utf8(response.status_code.to_string())
  raw_response.write_string_utf8("\r\n")
  for pair in headers.to_array() {
    let (key, value) = pair
    raw_response.write_string_utf8(key)
    raw_response.write_string_utf8(": ")
    raw_response.write_string_utf8(value)
    raw_response.write_string_utf8("\r\n")
  }
  raw_response.write_string_utf8("\r\n")
  if include_body && !response.raw_body.is_empty() {
    raw_response.write_bytes(response.raw_body)
  }
  conn.enter_passthrough_mode()
  conn.write(raw_response.contents())
  conn.flush()
  conn.close()
}

///|
fn Mocket::lookup_http_route(
  self : Mocket,
  http_method : String,
  request_path : String,
) -> HttpRouteLookup {
  match self.find_route(http_method, request_path) {
    Some((handler, params)) => return Found(handler, params)
    None => ()
  }
  if http_method == "HEAD" {
    match self.find_route_for_method("GET", request_path) {
      Some((handler, params)) => return Found(handler, params)
      None => ()
    }
  }
  let allow = self.allowed_methods(request_path, http_method == "OPTIONS")
  if allow.is_empty() {
    NotFound
  } else if http_method == "OPTIONS" {
    Options(allow_header_value(allow))
  } else {
    MethodNotAllowed(allow_header_value(allow))
  }
}

///|
async fn send_response_async(
  request : @http.Request,
  conn : @http.ServerConnection,
  response : HttpResponse,
  responder : &Responder,
) -> Unit raise Error {
  responder.options(response)
  let buffer = @buffer.new()
  responder.output(buffer)
  response.raw_body = buffer.to_bytes()
  let headers = response_headers_to_async(response.headers)
  append_cookie_headers(headers, response.cookies)
  if request.meth == Head {
    send_raw_response_async(conn, response, headers, false)
    return
  }
  if has_header_case_insensitive(headers, "Content-Encoding") {
    send_raw_response_async(conn, response, headers, true)
    return
  }
  conn.send_response(
    response.status_code.to_int(),
    response.status_code.to_string(),
    extra_headers=headers,
  )
  if !response.raw_body.is_empty() {
    conn.write(response.raw_body)
  }
  conn.end_response()
}

///|
async fn handle_request_async(
  app : Mocket,
  ws_runtime_id : String,
  request : @http.Request,
  body_reader : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit raise Error {
  let request_path = request_target_path(request.path)
  if is_websocket_upgrade_request(request) {
    match app.find_ws_route(request_path) {
      Some(ws_handler) => {
        handle_websocket_route_async(ws_runtime_id, request, conn, ws_handler)
        return
      }
      None => ()
    }
  }
  let http_method_text = request_method_to_string(request.meth)
  let request_body = body_reader.read_all().binary()
  let (params, handler) = match
    app.lookup_http_route(http_method_text, request_path) {
    Found(matched_handler, matched_params) => (matched_params, matched_handler)
    MethodNotAllowed(allow) => ({}, method_not_allowed_handler(allow))
    Options(allow) => ({}, options_handler(allow))
    NotFound => ({}, handle_not_found())
  }
  let event = {
    req: {
      http_method: http_method_text,
      url: request.path,
      headers: copy_async_headers(request.headers),
      raw_body: request_body,
    },
    res: HttpResponse::new(OK),
    params,
  }
  let responder = execute_middlewares(app.middlewares, event, handler)
  send_response_async(request, conn, event.res, responder)
}

///|
async fn run_native_server(
  app : Mocket,
  ws_runtime_id : String,
  server : @http.Server,
) -> Unit raise Error {
  server.run_forever((request, body_reader, conn) => {
    handle_request_async(app, ws_runtime_id, request, body_reader, conn)
  })
}

///|
async fn wait_for_shutdown_signal(shutdown : @async.Queue[Unit]) -> Unit {
  ignore(try? shutdown.get())
}

///|
pub async fn Mocket::serve_async_on(
  self : Mocket,
  server : @http.Server,
) -> Unit raise Error {
  let ws_runtime_id = next_ws_serve_runtime_id(self)
  defer cleanup_native_ws_runtime(ws_runtime_id)
  run_native_server(self, ws_runtime_id, server)
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
pub async fn Mocket::serve_async_on_until(
  self : Mocket,
  server : @http.Server,
  shutdown : @async.Queue[Unit],
) -> Unit raise Error {
  let ws_runtime_id = next_ws_serve_runtime_id(self)
  defer cleanup_native_ws_runtime(ws_runtime_id)
  @async.any([
    () => run_native_server(self, ws_runtime_id, server),
    () => wait_for_shutdown_signal(shutdown),
  ])
}

///|
pub async fn Mocket::serve_async(
  self : Mocket,
  port~ : Int,
) -> Unit raise Error {
  let addr = @socket.Addr::parse("0.0.0.0:\{port}")
  let server = @http.Server::new(addr, reuse_addr=true)
  self.serve_async_on(server)
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
pub async fn Mocket::serve_async_until(
  self : Mocket,
  port~ : Int,
  shutdown : @async.Queue[Unit],
) -> Unit raise Error {
  let addr = @socket.Addr::parse("0.0.0.0:\{port}")
  let server = @http.Server::new(addr, reuse_addr=true)
  self.serve_async_on_until(server, shutdown)
}
