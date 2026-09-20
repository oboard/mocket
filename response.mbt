///|
pub(all) struct HttpResponse {
  mut status_code : StatusCode
  headers : Map[@http.CaseInsensitiveString, StringView]
  cookies : Map[String, CookieItem]
  mut body : &Responder?
}

///|
/// Buffers output written through `@io.Writer` for backends that require a
/// complete byte slice before they can send a response.
pub(all) struct ResponseBuffer {
  buffer : Buffer
}

///|
pub fn ResponseBuffer::new() -> ResponseBuffer {
  { buffer: Buffer(), }
}

///|
pub fn ResponseBuffer::bytes(self : ResponseBuffer) -> Bytes {
  self.buffer.to_bytes()
}

///|
fn ResponseBuffer::write_data(self : ResponseBuffer, data : &@io.Data) -> Unit {
  self.buffer.write_bytes(data.binary())
}

///|
fn ResponseBuffer::write_chunk(
  self : ResponseBuffer,
  bytes : Bytes,
  offset~ : Int,
  len~ : Int,
) -> Int {
  self.buffer.write_bytes(bytes[offset:offset + len])
  len
}

///|
async fn ResponseBuffer::write_from_reader(
  self : ResponseBuffer,
  reader : &@io.Reader,
) -> Unit {
  self.write_data(reader.read_all())
}

///|
pub impl @io.Writer for ResponseBuffer with fn write(self, data) {
  self.write_data(data)
}

///|
pub impl @io.Writer for ResponseBuffer with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.write_chunk(bytes, offset~, len~)
}

///|
pub impl @io.Writer for ResponseBuffer with fn write_reader(self, reader) {
  self.write_from_reader(reader)
}

///|
pub async fn[T : BodyReader] HttpResponse::read_body(self : HttpResponse) -> T {
  let response_writer = ResponseBuffer::new()
  match self.body {
    Some(body) => body.output(response_writer)
    None => ()
  }
  let bytes = response_writer.bytes()
  T::from_request({
    http_method: "",
    url: "",
    query: "",
    headers: self.headers,
    reader: @io.MemoryReader(writer => writer.write(bytes)),
  })
}

///|
#alias(new, deprecated="Use `HttpResponse()` instead")
pub fn HttpResponse::HttpResponse(
  status_code : StatusCode,
  headers? : Map[@http.CaseInsensitiveString, StringView],
  cookies? : Map[String, CookieItem],
  body? : &Responder,
) -> HttpResponse {
  {
    status_code,
    headers: headers.unwrap_or({}),
    cookies: cookies.unwrap_or({}),
    body,
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
  let probe = HttpResponse(OK)
  body.options(probe)
  if probe.headers.get("Content-Type") is Some(content_type) &&
    !self.headers.contains("Content-Type") {
    self.headers["Content-Type"] = content_type
  }
  self.body = Some(body)
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
