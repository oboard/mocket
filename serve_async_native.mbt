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

/// Copies request headers from the async runtime.
/// Uses Map::from_iter for efficient bulk construction instead of
/// per-key insertion.

///|
fn copy_async_headers(headers : Map[String, String]) -> Map[String, String] {
  Map::from_iter(headers.iter())
}

///|
let cached_date_second : Ref[Int64] = Ref::new(0L)

///|
let cached_date_string : Ref[String] = Ref::new("")

///|
fn current_http_date() -> String {
  let now = @async.now() / 1000L
  if now != cached_date_second.val {
    cached_date_second.val = now
    cached_date_string.val = @mhttp.format_http_date(now)
  }
  cached_date_string.val
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
fn header_contains_token_case_insensitive(
  headers : Map[String, String],
  header_name : String,
  token_name : String,
) -> Bool {
  let normalized_token_name = token_name.to_lower()
  match @mhttp.get_header_case_insensitive(headers, header_name) {
    Some(value) => {
      for token in value.split(",") {
        if token.trim().to_lower() == normalized_token_name {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_websocket_upgrade_request(request : @http.Request) -> Bool {
  let has_connection_upgrade = header_contains_token_case_insensitive(
    request.headers,
    "connection",
    "upgrade",
  )
  let has_websocket_upgrade = match
    @mhttp.get_header_case_insensitive(request.headers, "upgrade") {
    Some(value) => value.trim().to_lower() == "websocket"
    None => false
  }
  has_connection_upgrade && has_websocket_upgrade
}

///|
fn looks_like_websocket_handshake_request(request : @http.Request) -> Bool {
  let websocket_upgrade_header = match
    @mhttp.get_header_case_insensitive(request.headers, "upgrade") {
    Some(value) => value.trim().to_lower() == "websocket"
    None => false
  }
  for pair in request.headers {
    let (key, _) = pair
    if key.to_lower().has_prefix("sec-websocket-") {
      return true
    }
  }
  is_websocket_upgrade_request(request) || websocket_upgrade_header
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
  if !@mhttp.has_header_case_insensitive(headers, "Date") {
    headers.set("Date", current_http_date())
  }
  if !@mhttp.has_header_case_insensitive(headers, "Content-Length") {
    headers.set("Content-Length", response.raw_body.length().to_string())
  }
  if !@mhttp.has_header_case_insensitive(headers, "Connection") {
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
  // Fast path: use output_bytes to avoid buffer allocation when possible
  match responder.output_bytes() {
    Some(bytes) => response.raw_body = bytes
    None => {
      let buffer = @buffer.new()
      responder.output(buffer)
      response.raw_body = buffer.to_bytes()
    }
  }
  // Use response headers directly, append cookies in-place
  let headers = response.headers
  append_cookie_headers(headers, response.cookies)
  if !@mhttp.has_header_case_insensitive(headers, "Date") {
    headers.set("Date", current_http_date())
  }
  if request.meth == Head {
    send_raw_response_async(conn, response, headers, false)
    return
  }
  if @mhttp.has_header_case_insensitive(headers, "Content-Encoding") {
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
async fn send_response_and_close_async(
  request : @http.Request,
  conn : @http.ServerConnection,
  response : HttpResponse,
) -> Unit raise Error {
  let headers = response.headers
  append_cookie_headers(headers, response.cookies)
  if !@mhttp.has_header_case_insensitive(headers, "Date") {
    headers.set("Date", current_http_date())
  }
  if !@mhttp.has_header_case_insensitive(headers, "Content-Length") {
    headers.set("Content-Length", response.raw_body.length().to_string())
  }
  headers.set("Connection", "close")
  if request.meth == Head {
    send_raw_response_async(conn, response, headers, false)
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
  conn.close()
}

///|
async fn send_request_entity_too_large_async(
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit raise Error {
  let response = HttpResponse::new(RequestEntityTooLarge).body(
    "Request Entity Too Large",
  )
  response.headers.set("Content-Type", "text/plain; charset=utf-8")
  send_response_and_close_async(request, conn, response)
}

///|
async fn send_request_timeout_async(
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit raise Error {
  let response = HttpResponse::new(RequestTimeout).body("Request Timeout")
  response.headers.set("Content-Type", "text/plain; charset=utf-8")
  send_response_and_close_async(request, conn, response)
}

///|
async fn send_not_found_async(
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit raise Error {
  let response = HttpResponse::new(NotFound).body("Not Found")
  response.headers.set("Content-Type", "text/plain; charset=utf-8")
  send_response_and_close_async(request, conn, response)
}

///|
fn request_content_length(request : @http.Request) -> Int? {
  match @mhttp.get_header_case_insensitive(request.headers, "content-length") {
    Some(value) => Some(@string.parse_int(value) catch { _ => return None })
    None => None
  }
}

///|
priv enum RequestBodyReadOutcome {
  Body(Bytes)
  RequestRejected
}

///|
fn next_native_request_body_chunk_size(limit : Int, total : Int) -> Int {
  let remaining = limit - total
  if remaining >= 1024 {
    1024
  } else {
    remaining + 1
  }
}

///|
fn native_request_body_chunk_exceeds_limit(
  limit : Int,
  total : Int,
  chunk_length : Int,
) -> Bool {
  chunk_length > limit - total
}

///|
async fn read_request_body_async(
  request : @http.Request,
  body_reader : &@io.Reader,
  conn : @http.ServerConnection,
  max_request_body_bytes : Int?,
) -> RequestBodyReadOutcome raise Error {
  match max_request_body_bytes {
    None => Body(body_reader.read_all().binary())
    Some(limit) => {
      match request_content_length(request) {
        Some(content_length) if content_length > limit => {
          send_request_entity_too_large_async(request, conn)
          return RequestRejected
        }
        _ => ()
      }
      let buffer = @buffer.new()
      let mut total = 0
      for ;; {
        let next_chunk_size = next_native_request_body_chunk_size(limit, total)
        guard body_reader.read_some(max_len=next_chunk_size) is Some(chunk) else {
          return Body(buffer.contents())
        }
        if native_request_body_chunk_exceeds_limit(limit, total, chunk.length()) {
          send_request_entity_too_large_async(request, conn)
          return RequestRejected
        }
        total += chunk.length()
        buffer.write_bytes(chunk)
      }
    }
  }
}

///|
async fn read_request_body_with_policy_async(
  request : @http.Request,
  body_reader : &@io.Reader,
  conn : @http.ServerConnection,
  max_request_body_bytes : Int?,
  request_body_read_timeout_ms : Int?,
) -> RequestBodyReadOutcome raise Error {
  match request_body_read_timeout_ms {
    Some(request_body_read_timeout_ms) =>
      match
        @async.with_timeout_opt(request_body_read_timeout_ms, () => {
          read_request_body_async(
            request, body_reader, conn, max_request_body_bytes,
          )
        }) {
        Some(outcome) => outcome
        None => {
          send_request_timeout_async(request, conn)
          RequestRejected
        }
      }
    None =>
      read_request_body_async(
        request, body_reader, conn, max_request_body_bytes,
      )
  }
}

///|
async fn handle_request_async(
  app : Mocket,
  ws_runtime_id : String,
  request : @http.Request,
  body_reader : &@io.Reader,
  conn : @http.ServerConnection,
  options : NativeServeOptions,
) -> Unit raise Error {
  let request_path = @mhttp.request_target_path(request.path)
  let strict_websocket_upgrade = is_websocket_upgrade_request(request)
  // Skip expensive WebSocket handshake inspection when no WS routes exist
  let has_ws_routes = !app.ws_static_routes.is_empty() ||
    !app.ws_dynamic_routes.is_empty()
  let websocket_like_request = if strict_websocket_upgrade {
    true
  } else if has_ws_routes {
    looks_like_websocket_handshake_request(request)
  } else {
    false
  }
  if websocket_like_request {
    let websocket_max_message_bytes = resolve_native_websocket_max_message_bytes(
      options,
    )
    let websocket_outgoing_queue_capacity = match
      resolve_native_websocket_outgoing_queue_capacity(options) {
      Some(capacity) => capacity
      None => DEFAULT_NATIVE_WS_OUTGOING_QUEUE_CAPACITY
    }
    let websocket_overflow_policy = resolve_native_websocket_overflow_policy(
      options,
    )
    let websocket_read_timeout_ms = resolve_native_websocket_read_timeout_ms(
      options,
    )
    match app.find_ws_route(request_path) {
      Some(ws_handler) => {
        handle_websocket_route_async(
          ws_runtime_id, request, conn, ws_handler, websocket_max_message_bytes,
          websocket_outgoing_queue_capacity, websocket_overflow_policy, websocket_read_timeout_ms,
        )
        return
      }
      None if strict_websocket_upgrade => {
        send_not_found_async(request, conn)
        return
      }
      None => ()
    }
  }
  let http_method_text = request_method_to_string(request.meth)
  // Skip body reading for methods that typically have no body,
  // unless Content-Length indicates a body is present (for size limit enforcement)
  let has_body_hint = request_content_length(request) is Some(len) && len > 0
  let request_body : Bytes = if !has_body_hint &&
    request.meth is (Get | Head | Delete | Options | Trace) {
    b""
  } else {
    let max_request_body_bytes = resolve_native_max_request_body_bytes(options)
    let request_body_read_timeout_ms = resolve_native_request_body_read_timeout_ms(
      options,
    )
    match
      read_request_body_with_policy_async(
        request, body_reader, conn, max_request_body_bytes, request_body_read_timeout_ms,
      ) {
      Body(request_body) => request_body
      RequestRejected => return
    }
  }
  let (params, handler) = match
    app.lookup_http_route(http_method_text, request_path) {
    Found(matched_handler, matched_params) => (matched_params, matched_handler)
    MethodNotAllowed(allow) => ({}, method_not_allowed_handler(allow))
    Options(allow) => ({}, options_handler(allow))
    NotFound =>
      match app.not_found_handler {
        Some(handler) => ({}, handler)
        None => ({}, handle_not_found())
      }
  }
  let event = {
    req: HttpRequest::from_method_string(
      http_method_text,
      request.path,
      copy_async_headers(request.headers),
      request_body,
    ),
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
  options : NativeServeOptions,
) -> Unit raise Error {
  let max_connections = resolve_native_max_connections(options)
  let _ = resolve_native_max_request_body_bytes(options)
  let _ = resolve_native_request_body_read_timeout_ms(options)
  let _ = resolve_native_websocket_max_message_bytes(options)
  let _ = resolve_native_websocket_outgoing_queue_capacity(options)
  let _ = resolve_native_websocket_overflow_policy(options)
  let _ = resolve_native_websocket_read_timeout_ms(options)
  match max_connections {
    Some(max_connections) =>
      server.run_forever(allow_failure=true, max_connections~, (
        request,
        body_reader,
        conn,
      ) => {
        handle_request_async(
          app, ws_runtime_id, request, body_reader, conn, options,
        )
      })
    None =>
      server.run_forever(allow_failure=true, (request, body_reader, conn) => {
        handle_request_async(
          app, ws_runtime_id, request, body_reader, conn, options,
        )
      })
  }
}

///|
async fn wait_for_shutdown_signal(shutdown : @async.Queue[Unit]) -> Unit {
  ignore(try? shutdown.get())
}

///|
pub async fn Mocket::serve_on(
  self : Mocket,
  server : @http.Server,
) -> Unit raise Error {
  self.serve_on_with(server, NativeServeOptions::new())
}

///|
/// Serve using explicit native async runtime options.
/// `max_connections`, if present, limits the number of client connections
/// handled in parallel by the underlying `@http.Server`.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
/// `request_body_read_timeout_ms`, if present, rejects slow request bodies
/// with `408 Request Timeout`.
/// `websocket_max_message_bytes`, if present, closes websocket connections
/// with `1009 MessageTooBig` when an inbound message exceeds that many bytes.
/// `websocket_outgoing_queue_capacity`, if present, bounds buffered outbound
/// websocket messages per connection.
/// `websocket_overflow_policy`, if present, chooses whether a full outbound
/// websocket queue drops the oldest or latest message.
/// `websocket_read_timeout_ms`, if present, closes websocket connections
/// after that many milliseconds waiting for the next inbound message.
pub async fn Mocket::serve_on_with(
  self : Mocket,
  server : @http.Server,
  options : NativeServeOptions,
) -> Unit raise Error {
  let ws_runtime_id = next_ws_serve_runtime_id(self)
  defer cleanup_native_ws_runtime(ws_runtime_id)
  run_native_server(self, ws_runtime_id, server, options)
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
pub async fn Mocket::serve_on_until(
  self : Mocket,
  server : @http.Server,
  shutdown : @async.Queue[Unit],
) -> Unit raise Error {
  self.serve_on_until_with(server, shutdown, NativeServeOptions::new())
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
/// `max_connections`, if present, limits the number of client connections
/// handled in parallel by the underlying `@http.Server`.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
/// `request_body_read_timeout_ms`, if present, rejects slow request bodies
/// with `408 Request Timeout`.
/// `websocket_max_message_bytes`, if present, closes websocket connections
/// with `1009 MessageTooBig` when an inbound message exceeds that many bytes.
/// `websocket_outgoing_queue_capacity`, if present, bounds buffered outbound
/// websocket messages per connection.
/// `websocket_overflow_policy`, if present, chooses whether a full outbound
/// websocket queue drops the oldest or latest message.
/// `websocket_read_timeout_ms`, if present, closes websocket connections
/// after that many milliseconds waiting for the next inbound message.
pub async fn Mocket::serve_on_until_with(
  self : Mocket,
  server : @http.Server,
  shutdown : @async.Queue[Unit],
  options : NativeServeOptions,
) -> Unit raise Error {
  let ws_runtime_id = next_ws_serve_runtime_id(self)
  defer cleanup_native_ws_runtime(ws_runtime_id)
  @async.any([
    () => run_native_server(self, ws_runtime_id, server, options),
    () => wait_for_shutdown_signal(shutdown),
  ])
}

///|
pub async fn Mocket::serve(self : Mocket, port~ : Int) -> Unit raise Error {
  self.serve_with(port~, NativeServeOptions::new())
}

///|
/// Serve on `port` using explicit native async runtime options.
/// `max_connections`, if present, limits the number of client connections
/// handled in parallel by the underlying `@http.Server`.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
/// `request_body_read_timeout_ms`, if present, rejects slow request bodies
/// with `408 Request Timeout`.
/// `websocket_max_message_bytes`, if present, closes websocket connections
/// with `1009 MessageTooBig` when an inbound message exceeds that many bytes.
/// `websocket_outgoing_queue_capacity`, if present, bounds buffered outbound
/// websocket messages per connection.
/// `websocket_overflow_policy`, if present, chooses whether a full outbound
/// websocket queue drops the oldest or latest message.
/// `websocket_read_timeout_ms`, if present, closes websocket connections
/// after that many milliseconds waiting for the next inbound message.
pub async fn Mocket::serve_with(
  self : Mocket,
  port~ : Int,
  options : NativeServeOptions,
) -> Unit raise Error {
  let _ = resolve_native_max_connections(options)
  let _ = resolve_native_max_request_body_bytes(options)
  let _ = resolve_native_request_body_read_timeout_ms(options)
  let _ = resolve_native_websocket_max_message_bytes(options)
  let _ = resolve_native_websocket_outgoing_queue_capacity(options)
  let _ = resolve_native_websocket_overflow_policy(options)
  let _ = resolve_native_websocket_read_timeout_ms(options)
  let addr = @socket.Addr::parse("0.0.0.0:\{port}")
  let server = @http.Server::new(addr, reuse_addr=true)
  self.serve_on_with(server, options)
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
pub async fn Mocket::serve_until(
  self : Mocket,
  port~ : Int,
  shutdown : @async.Queue[Unit],
) -> Unit raise Error {
  self.serve_until_with(port~, shutdown, NativeServeOptions::new())
}

///|
/// Stop serving when `shutdown` receives a unit or is closed.
/// `shutdown.put(())` wakes one waiter; `shutdown.close()` broadcasts to all waiters.
/// Shutdown is cancellation-based: active requests and websocket sessions
/// are aborted rather than drained to completion.
/// `max_connections`, if present, limits the number of client connections
/// handled in parallel by the underlying `@http.Server`.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
/// `request_body_read_timeout_ms`, if present, rejects slow request bodies
/// with `408 Request Timeout`.
/// `websocket_max_message_bytes`, if present, closes websocket connections
/// with `1009 MessageTooBig` when an inbound message exceeds that many bytes.
/// `websocket_outgoing_queue_capacity`, if present, bounds buffered outbound
/// websocket messages per connection.
/// `websocket_overflow_policy`, if present, chooses whether a full outbound
/// websocket queue drops the oldest or latest message.
/// `websocket_read_timeout_ms`, if present, closes websocket connections
/// after that many milliseconds waiting for the next inbound message.
pub async fn Mocket::serve_until_with(
  self : Mocket,
  port~ : Int,
  shutdown : @async.Queue[Unit],
  options : NativeServeOptions,
) -> Unit raise Error {
  let _ = resolve_native_max_connections(options)
  let _ = resolve_native_max_request_body_bytes(options)
  let _ = resolve_native_request_body_read_timeout_ms(options)
  let _ = resolve_native_websocket_max_message_bytes(options)
  let _ = resolve_native_websocket_outgoing_queue_capacity(options)
  let _ = resolve_native_websocket_overflow_policy(options)
  let _ = resolve_native_websocket_read_timeout_ms(options)
  let addr = @socket.Addr::parse("0.0.0.0:\{port}")
  let server = @http.Server::new(addr, reuse_addr=true)
  self.serve_on_until_with(server, shutdown, options)
}
