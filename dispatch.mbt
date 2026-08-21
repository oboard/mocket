///|
/// Split a raw HTTP request-target into its path and query string.
///
/// Routes match against the path; the query is retained separately on the
/// `HttpRequest`. A `#fragment` is never used for routing, so it is stripped
/// from the query rather than exposed.
fn split_request_target(target : String) -> (String, String) {
  let (path, rest) = match target.find("?") {
    Some(q) => (target[:q].to_owned(), target[q + 1:].to_owned())
    None => (target, "")
  }
  let query = match rest.find("#") {
    Some(f) => rest[:f].to_owned()
    None => rest
  }
  (path, query)
}

///|
/// Whether a request carries a body: POST/PUT/PATCH always may, and any
/// method with an explicit (non-empty) `content-length` or a
/// `transfer-encoding` (i.e. chunked) frame is treated as having a body.
/// The same rule is used by every backend so bodies are read consistently.
fn request_has_body(
  http_method : String,
  headers : Map[@http.CaseInsensitiveString, StringView],
) -> Bool {
  match http_method {
    "POST" | "PUT" | "PATCH" => true
    _ =>
      headers.get("transfer-encoding") is Some(_) ||
      headers.get("content-length")
        .map(value => value.to_owned().trim() != "0")
        .unwrap_or(false)
  }
}

///|
pub async fn dispatch_http(
  mocket : Mocket,
  http_method : String,
  url : String,
  headers : Map[@http.CaseInsensitiveString, StringView],
  raw_body : Bytes,
) -> HttpResponse {
  let (path, query) = split_request_target(url)
  let (params, handler) = match mocket.find_route(http_method, path) {
    Some((h, p)) => (p, h)
    _ => ({}, handle_not_found())
  }
  let event = {
    req: { http_method, url: path, query, raw_body, headers },
    res: HttpResponse::new(OK),
    params,
  }
  let responder = mocket.execute_middlewares(event, handler) catch {
    err => {
      if @async.is_cancellation_error(err) {
        raise err
      }
      mocket.handle_request_error(event, err)
    }
  }
  responder.options(event.res)
  let buf = Buffer()
  responder.output(buf)
  event.res.raw_body = buf.to_bytes()
  event.res
}