///|
pub async fn dispatch_http(
  mocket : Mocket,
  http_method : String,
  url : String,
  headers : Map[StringView, StringView],
  raw_body : Bytes,
) -> HttpResponse noraise {
  let (params, handler) = match mocket.find_route(http_method, url) {
    Some((h, p)) => (p, h)
    _ => ({}, handle_not_found())
  }
  let event = {
    req: { http_method, url, raw_body, headers },
    res: HttpResponse::new(OK),
    params,
  }
  let responder = mocket.execute_middlewares(event, handler)
  responder.options(event.res)
  let buf = @buffer.new()
  responder.output(buf)
  event.res.raw_body = buf.to_bytes()
  event.res
}
