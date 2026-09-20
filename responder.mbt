///|
pub(open) trait Responder {
  fn options(Self, res : HttpResponse) -> Unit
  async fn output(Self, writer : &@io.Writer) -> Unit
}

///|
async fn &ToJson::write_response(self : &ToJson, writer : &@io.Writer) -> Unit {
  writer.write(@utf8.encode(self.to_json().stringify()))
}

///|
pub impl Responder for &ToJson with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/json; charset=utf-8"
}

///|
pub impl Responder for &ToJson with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn HttpResponse::write_response(
  self : HttpResponse,
  writer : &@io.Writer,
) -> Unit {
  match self.body {
    Some(body) => body.output(writer)
    None => ()
  }
}

///|
pub impl Responder for HttpResponse with fn options(self, res) -> Unit {
  res.status_code = self.status_code
  res.headers.merge_in_place(self.headers)
}

///|
pub impl Responder for HttpResponse with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn Json::write_response(self : Json, writer : &@io.Writer) -> Unit {
  writer.write(@utf8.encode(@json.to_json(self).stringify()))
}

///|
pub impl Responder for Json with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/json; charset=utf-8"
}

///|
pub impl Responder for Json with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn Bytes::write_response(self : Bytes, writer : &@io.Writer) -> Unit {
  writer.write(self)
}

///|
pub impl Responder for Bytes with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "application/octet-stream"
}

///|
pub impl Responder for Bytes with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn String::write_response(self : String, writer : &@io.Writer) -> Unit {
  writer.write(self)
}

///|
pub impl Responder for String with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for String with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn StringView::write_response(
  self : StringView,
  writer : &@io.Writer,
) -> Unit {
  writer.write(self)
}

///|
pub impl Responder for StringView with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/plain; charset=utf-8"
}

///|
pub impl Responder for StringView with fn output(self, writer) {
  self.write_response(writer)
}

///|
struct Html(String)

///|
async fn Html::write_response(self : Html, writer : &@io.Writer) -> Unit {
  writer.write(self.0)
}

///|
pub impl Responder for Html with fn options(_, res) -> Unit {
  res.headers["Content-Type"] = "text/html; charset=utf-8"
}

///|
pub impl Responder for Html with fn output(self, writer) {
  self.write_response(writer)
}

///|
pub fn html(html : &Show) -> &Responder {
  Html(html.to_string())
}

///|
pub fn text(text : &Show) -> &Responder {
  text.to_string()
}
