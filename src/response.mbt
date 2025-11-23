///|
pub(all) struct HttpResponse {
  mut status_code : Int
  headers : Map[StringView, StringView]
  cookies : Map[String, CookieItem]
  mut raw_body : Bytes
}

///|
pub fn HttpResponse::new(
  status_code : Int,
  headers? : Map[StringView, StringView],
  cookies? : Map[String, CookieItem],
  raw_body? : Bytes,
) -> HttpResponse {
  HttpResponse::{
    status_code,
    headers: headers.unwrap_or({}),
    cookies: cookies.unwrap_or({}),
    raw_body: raw_body.unwrap_or(""),
  }
}

///|
pub fn HttpResponse::ok() -> HttpResponse {
  HttpResponse::new(200)
}

///|
pub fn HttpResponse::not_found() -> HttpResponse {
  HttpResponse::new(404)
}

///|
pub fn HttpResponse::not_modified() -> HttpResponse {
  HttpResponse::new(304)
}

///|
pub fn HttpResponse::body(
  self : HttpResponse,
  body : &Responder,
) -> HttpResponse {
  let buf = @buffer.new()
  body.output(buf)
  self.raw_body = buf.to_bytes()
  self
}

///|
pub fn HttpResponse::to_responder(self : HttpResponse) -> &Responder {
  self
}
