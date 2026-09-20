///|
/// Streams the parts of a multipart/form-data body in their original order.
struct Form {
  reader : Reader
}

///|
pub fn Form::Form(
  source : &@io.Reader,
  boundary~ : String,
) -> Self raise MultipartError {
  { reader: Reader(source, boundary~), }
}

///|
/// Advancing discards any unread bytes from the previous part.
/// Bodies remain bytes: charset and Content-Transfer-Encoding are not decoded.
/// Nested multipart bodies are exposed as parts and can be traversed with Reader.
pub async fn Form::next_part(self : Self) -> FormPart? {
  guard self.reader.next_part() is Some((headers, source)) else { None }
  guard headers.get("Content-Disposition") is Some(disposition) else {
    raise MultipartError("form part is missing Content-Disposition")
  }
  let (kind, parameters) = parse_header_value(disposition)
  guard @http.CaseInsensitiveString(kind) == "form-data" else {
    raise MultipartError("form part requires a form-data disposition")
  }
  guard parameters.get("name") is Some(name) else {
    raise MultipartError("form part is missing the name parameter")
  }
  let filename = parameters.get("filename")
  Some({ source, name, filename, headers, })
}

///|
struct FormPart {
  source : &@io.Reader
  name : String
  filename : String?
  headers : @http.Headers
}

///|
/// Returns the supplied filename. When saving a file, the caller must discard
/// directory components and choose a suitable local name (RFC 7578 §4.2).
/// Percent escapes remain literal because multipart/form-data does not identify
/// whether a filename uses the optional percent-encoding convention.
pub fn FormPart::filename(self : Self) -> String? {
  self.filename
}

///|
pub fn FormPart::name(self : Self) -> String {
  self.name
}

///|
/// Returns the full Content-Type value, including any charset parameter.
/// RFC 7578 §4.4 specifies text/plain when the header is absent.
pub fn FormPart::content_type(self : Self) -> String {
  self.headers.get("Content-Type").unwrap_or("text/plain")
}

///|
pub fn FormPart::headers(self : Self) -> @http.Headers {
  self.headers
}

///|
// Share both hooks with the source so Reader::next_part also drains any bytes
// buffered by read_until/read_some through this FormPart.
pub impl @io.Reader for FormPart with fn _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.source)
}

///|
pub impl @io.Reader for FormPart with fn _direct_read(
  self,
  buffer,
  offset~,
  max_len~,
) {
  @io.Reader::_direct_read(self.source, buffer, offset~, max_len~)
}
