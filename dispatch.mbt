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
      headers
      .get("content-length")
      .map(value => value.to_owned().trim() != "0")
      .unwrap_or(false)
  }
}

///|
/// Dispatch a request whose body is still available as an async reader.
/// BodyReader implementations decide whether to read it incrementally or buffer
/// it. This is used by the native HTTP server.
async fn dispatch_http_reader(
  mocket : Mocket,
  http_method : String,
  url : String,
  headers : Map[@http.CaseInsensitiveString, StringView],
  body_reader : &@io.Reader,
) -> HttpResponse {
  let (path, query) = split_request_target(url)
  let (params, handler) = match mocket.find_route(http_method, path) {
    Some((h, p)) => (p, h)
    _ => ({}, handle_not_found())
  }
  let event = {
    req: { http_method, url: path, query, headers, reader: body_reader, },
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

///|
pub async fn dispatch_http(
  mocket : Mocket,
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
