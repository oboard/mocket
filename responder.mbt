/// Trait for types that can be sent as an HTTP response body.
///
/// Implementors define `options` to configure response headers (e.g. Content-Type)
/// and `output` to write the body bytes into the buffer.

///|
pub(open) trait Responder {
  options(Self, res : HttpResponse) -> Unit
  output(Self, buf : @buffer.Buffer) -> Unit
}

///|
pub impl Responder for &ToJson with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "application/json; charset=utf-8",
  )
}

///|
pub impl Responder for &ToJson with output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.to_json().stringify()))
}

///|
pub impl Responder for HttpRequest with options(self, res) -> Unit {
  @mhttp.merge_headers_case_insensitive(res.headers, self.headers)
}

///|
pub impl Responder for HttpRequest with output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for HttpResponse with options(self, res) -> Unit {
  res.status_code = self.status_code
  @mhttp.merge_headers_case_insensitive(res.headers, self.headers)
}

///|
pub impl Responder for HttpResponse with output(self, buf) -> Unit {
  buf.write_bytes(self.raw_body)
}

///|
pub impl Responder for Json with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "application/json; charset=utf-8",
  )
}

///|
pub impl Responder for Json with output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.to_json().stringify()))
}

///|
pub impl Responder for Bytes with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "application/octet-stream",
  )
}

///|
pub impl Responder for Bytes with output(self, buf) -> Unit {
  buf.write_bytes(self)
}

///|
pub impl Responder for String with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "text/plain; charset=utf-8",
  )
}

///|
pub impl Responder for String with output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self))
}

///|
pub impl Responder for StringView with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "text/plain; charset=utf-8",
  )
}

///|
pub impl Responder for StringView with output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self))
}

///|
struct Html(String)

///|
pub impl Responder for Html with options(_, res) -> Unit {
  @mhttp.set_missing_header_case_insensitive(
    res.headers,
    "Content-Type",
    "text/html; charset=utf-8",
  )
}

///|
pub impl Responder for Html with output(self, buf) -> Unit {
  buf.write_bytes(@utf8.encode(self.0))
}

/// Creates an HTML responder from any `Show` value, setting the Content-Type to `text/html`.

///|
pub fn html(html : &Show) -> &Responder {
  Html(html.to_string())
}

/// Creates a plain-text responder from any `Show` value, setting the Content-Type to `text/plain`.

///|
pub fn text(text : &Show) -> &Responder {
  text.to_string()
}
