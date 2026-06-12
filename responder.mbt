///|
pub(open) trait Responder {
  fn options(Self, res : HttpResponse) -> Unit
  fn output(Self, buf : @buffer.Buffer) -> Unit
}

///|
pub impl Responder for &ToJson with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/json; charset=utf-8"
}

///|
pub impl Responder for &ToJson with fn output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.to_json().stringify()))
}

///|
pub impl Responder for HttpRequest with fn options(self, res) -> Unit {
  res.headers.merge_in_place(self.headers)
}

///|
pub impl Responder for HttpRequest with fn output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for HttpResponse with fn options(self, res) -> Unit {
  res.status_code = self.status_code
  res.headers.merge_in_place(self.headers)
}

///|
pub impl Responder for HttpResponse with fn output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for Json with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/json; charset=utf-8"
}

///|
pub impl Responder for Json with fn output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.to_json().stringify()))
}

///|
pub impl Responder for Bytes with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/octet-stream"
}

///|
pub impl Responder for Bytes with fn output(self, buf) -> Unit {
  buf.write_bytes(self)
}

///|
pub impl Responder for String with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for String with fn output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self))
}

///|
pub impl Responder for StringView with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for StringView with fn output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self))
}

///|
struct Html(String)

///|
pub impl Responder for Html with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/html; charset=utf-8"
}

///|
pub impl Responder for Html with fn output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.0))
}

///|
pub fn html(html : &Show) -> &Responder {
  Html(html.to_string())
}

///|
pub fn text(text : &Show) -> &Responder {
  text.to_string()
}
