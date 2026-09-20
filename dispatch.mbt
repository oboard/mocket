///|
/// Split a raw HTTP request-target into its path and query string.
///
/// Routes match against the path; the query is retained separately on the
/// `HttpRequest`. A `#fragment` is never used for routing, so it is stripped
/// from the query rather than exposed.
fn split_request_target(target : String) -> (String, String) {
  let target = match target.find("#") {
    Some(fragment) => target[:fragment].to_owned()
    None => target
  }
  match target.find("?") {
    Some(query) => (target[:query].to_owned(), target[query + 1:].to_owned())
    None => (target, "")
  }
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
      headers
      .get("content-length")
      .map(value => value.to_owned().trim() != "0")
      .unwrap_or(false)
  }
}

///|
pub async fn dispatch_http(
  mocket : App,
  http_method : String,
  url : String,
  headers : Map[@http.CaseInsensitiveString, StringView],
  body : Bytes,
) -> HttpResponse {
  let (path, query) = split_request_target(url)
  let (params, handler) = match mocket.find_route(http_method, path) {
    Some((h, p)) => (p, h)
    _ => ({}, handle_not_found())
  }
  let event = {
    req: {
      http_method,
      url: path,
      query,
      headers,
      reader: @io.MemoryReader(writer => writer.write(body)),
    },
    res: HttpResponse(OK),
    params,
  }
  let responder = mocket.execute_middlewares(event, handler) catch {
    err => mocket.handle_request_error(event, err)
  }
  responder.options(event.res)
  event.res.body = Some(responder)
  event.res
}
