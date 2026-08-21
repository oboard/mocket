///|
pub(all) struct HttpResponse {
  mut status_code : StatusCode
  headers : Map[StringView, StringView]
  cookies : Map[String, CookieItem]
  mut raw_body : Bytes
}

///|
pub fn[T : BodyReader] HttpResponse::read_body(self : HttpResponse) -> T raise {
  T::from_request({
    http_method: "",
    url: "",
    headers: self.headers,
    raw_body: self.raw_body,
  })
}

///|
pub fn HttpResponse::new(
  status_code : StatusCode,
  headers? : Map[StringView, StringView],
  cookies? : Map[String, CookieItem],
  raw_body? : Bytes,
) -> HttpResponse {
  {
    status_code,
    headers: headers.unwrap_or({}),
    cookies: cookies.unwrap_or({}),
    raw_body: raw_body.unwrap_or(b""),
  }
}

///|
/// Sets the response body from any `Responder`.
///
/// The body responder's default `Content-Type` is carried into this
/// response only when no explicit `"Content-Type"` header was set on this
/// response. Explicit response headers always take precedence.
///
/// Only the default `Content-Type` is inferred. The responder's status,
/// other headers, cookies, and any other responder effects are not merged,
/// so `self.status_code` is preserved.
pub fn HttpResponse::body(
  self : HttpResponse,
  body : &Responder,
) -> HttpResponse {
  let probe = HttpResponse::new(OK)
  body.options(probe)
  if probe.headers.get("Content-Type") is Some(content_type) &&
    !self.headers.contains("Content-Type") {
    self.headers["Content-Type"] = content_type
  }
  let buf = Buffer()
  body.output(buf)
  self.raw_body = buf.to_bytes()
  self
}

///|
/// Sets a JSON response body.
///
/// Infers `Content-Type: application/json; charset=utf-8` under the same
/// rule as `HttpResponse::body`: an explicit `"Content-Type"` header already
/// present on this response takes precedence, and `self.status_code` is
/// preserved.
pub fn HttpResponse::json(self : HttpResponse, obj : &ToJson) -> HttpResponse {
  self.body(obj.to_json())
}

///|
pub fn HttpResponse::to_responder(self : HttpResponse) -> &Responder {
  self
}

///|
test "read_response_body" {
  let res = HttpResponse::new(OK, raw_body=b"{\"Hello\":\"Response\"}")
  let text : String = res.read_body()
  let json : Json = res.read_body()
  inspect(
    text,
    content=(
      #|{"Hello":"Response"}
    ),
  )
  json_inspect(json, content={ "Hello": "Response" })
}
