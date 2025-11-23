///|
pub(open) trait Responder {
  options(Self, res : HttpResponse) -> Unit
  output(Self, buf : @buffer.Buffer) -> Unit
}

///|
pub impl Responder for HttpRequest with options(self, res) -> Unit {
  res.status_code = 200
  res.headers.merge_in_place(self.headers)
}

///|
pub impl Responder for HttpRequest with output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for HttpResponse with options(self, res) -> Unit {
  res.status_code = self.status_code
  res.headers.merge_in_place(self.headers)
}

///|
pub impl Responder for HttpResponse with output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for Json with options(_, res) -> Unit {
  res.status_code = 200
  res.headers["Content-Type"] = "application/json; charset=utf-8"
}

///|
pub impl Responder for Json with output(self, buf) -> Unit {
  buf.write_string(self.stringify())
}

///|
pub impl Responder for Bytes with options(_, res) -> Unit {
  res.status_code = 200
  res.headers["Content-Type"] = "application/octet-stream"
}

///|
pub impl Responder for Bytes with output(self, buf) -> Unit {
  buf.write_bytes(self)
}

///|
pub impl Responder for String with options(_, res) -> Unit {
  res.status_code = 200
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for String with output(self, buf) -> Unit {
  buf.write_string(self)
}

///|
pub impl Responder for StringView with options(_, res) -> Unit {
  res.status_code = 200
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for StringView with output(self, buf) -> Unit {
  buf.write_string(self.to_string())
}

///|
struct Html(StringView)

///|
type Empty

///|
pub impl Responder for Html with options(_, res) -> Unit {
  res.status_code = 200
  res.headers["Content-Type"] = "text/html; charset=utf-8"
}

///|
pub impl Responder for Html with output(self, buf) -> Unit {
  buf.write_string(self.0.to_string())
}

///|
pub fn json(json : Json) -> &Responder {
  json
}

///|
pub fn html(html : &Show) -> &Responder {
  Html(html.to_string())
}

///|
pub fn text(text : &Show) -> &Responder {
  text.to_string()
}

///|
pub fn bytes(bytes : Bytes) -> &Responder {
  bytes
}
