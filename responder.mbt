/// Trait for types that can be sent as an HTTP response body.
///
/// Implementors define `options` to configure response headers (e.g. Content-Type)
/// and `output` to write the body bytes into the buffer.
///
/// Built-in implementations:
/// - `String` / `StringView` → `text/plain; charset=utf-8`
/// - `Bytes` → `application/octet-stream`
/// - `Json` / `&ToJson` → `application/json; charset=utf-8`
/// - `HttpResponse` → uses the response's own status, headers, and body
/// - `HttpRequest` → forwards the request body (useful for proxying)
/// - `Html` (via `html()` helper) → `text/html; charset=utf-8`
///
/// To make your own type a responder, implement the trait:
/// ```
/// struct MyData { value : Int }
/// pub impl Responder for MyData with options(_, res) {
///   res.headers.set("Content-Type", "text/plain")
/// }
/// pub impl Responder for MyData with output(self, buf) {
///   buf.write_string_utf8(self.value.to_string())
/// }
/// pub impl Responder for MyData with output_bytes(_) -> Bytes? { None }
/// ```

///|
pub(open) trait Responder {
  options(Self, res : HttpResponse) -> Unit
  output(Self, buf : @buffer.Buffer) -> Unit
  /// Returns pre-encoded bytes directly, bypassing the buffer allocation.
  /// Returns `None` to fall back to `output()`.
  /// Override this for types that already hold their response as bytes
  /// (e.g. HttpResponse, Bytes) to avoid a copy through the intermediate buffer.
  output_bytes(Self) -> Bytes?
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
  buf.write_string_utf8(self.to_json().stringify())
}

///|
pub impl Responder for &ToJson with output_bytes(_self) -> Bytes? {
  None
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
pub impl Responder for HttpRequest with output_bytes(self) -> Bytes? {
  if self.raw_body.is_empty() {
    None
  } else {
    Some(self.raw_body)
  }
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
pub impl Responder for HttpResponse with output_bytes(self) -> Bytes? {
  if self.raw_body.is_empty() {
    None
  } else {
    Some(self.raw_body)
  }
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
  buf.write_string_utf8(self.to_json().stringify())
}

///|
pub impl Responder for Json with output_bytes(_self) -> Bytes? {
  None
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
pub impl Responder for Bytes with output_bytes(self) -> Bytes? {
  if self.is_empty() {
    None
  } else {
    Some(self)
  }
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
  buf.write_string_utf8(self)
}

///|
pub impl Responder for String with output_bytes(_self) -> Bytes? {
  None
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
  buf.write_string_utf8(self)
}

///|
pub impl Responder for StringView with output_bytes(_self) -> Bytes? {
  None
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
  buf.write_string_utf8(self.0)
}

///|
pub impl Responder for Html with output_bytes(_self) -> Bytes? {
  None
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
