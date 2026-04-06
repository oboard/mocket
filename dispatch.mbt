///|
/// Dispatches a synthetic HTTP request through the full routing + middleware
/// pipeline and returns `(status_code, headers, body_bytes)`.
pub async fn Mocket::dispatch(
  self : Mocket,
  http_method : String,
  url : String,
  headers : Map[String, String],
  body : Bytes,
) -> (StatusCode, Map[String, String], Bytes) {
  let request_path = @mhttp.request_target_path(url)
  // Look up route
  let (params, handler) = match
    self.lookup_http_route(http_method, request_path) {
    Found(matched_handler, matched_params) => (matched_params, matched_handler)
    MethodNotAllowed(allow) => ({}, method_not_allowed_handler(allow))
    Options(allow) => ({}, options_handler(allow))
    NotFound =>
      match self.not_found_handler {
        Some(handler) => ({}, handler)
        None => ({}, handle_not_found())
      }
  }
  // Construct event
  let event = {
    req: HttpRequest::from_method_string(http_method, url, headers, body),
    res: HttpResponse(OK),
    params,
  }
  // Execute middleware chain + handler
  let responder = execute_middlewares(self.middlewares, event, handler)
  // Apply responder to response
  responder.options(event.res)
  match responder.output_bytes() {
    Some(bytes) => event.res.raw_body = bytes
    None => {
      let buf = @buffer.new()
      responder.output(buf)
      event.res.raw_body = buf.to_bytes()
    }
  }
  (event.res.status_code, event.res.headers, event.res.raw_body)
}
