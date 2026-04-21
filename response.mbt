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
  HttpResponse::{
    status_code,
    headers: headers.unwrap_or({}),
    cookies: cookies.unwrap_or({}),
    raw_body: raw_body.unwrap_or(b""),
  }
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
