///|
pub type Callback = async (&@io.Writer) -> Unit

///|
struct Writer {
  target : &@io.Writer
  boundary : String
  mut started : Bool
  mut finished : Bool
}

///|
/// Create a multipart writer. The caller must choose a boundary that does not
/// occur as a delimiter in any part (RFC 2046 section 5.1.1).
pub fn Writer::Writer(
  target : &@io.Writer,
  boundary~ : String,
) -> Self raise MultipartError {
  validate_boundary(boundary)
  { target, boundary, started: false, finished: false, }
}

///|
/// Write a part without buffering its body. Call parts sequentially, and use
/// the callback's writer only until the callback returns.
pub async fn Writer::write_part(
  self : Self,
  headers~ : @http.Headers,
  callback : Callback,
) -> Unit {
  guard !self.finished else {
    raise MultipartError("multipart writer is finished")
  }
  for name, value in headers {
    validate_header(name.0, value)
  }
  if self.started {
    self.target.write("\r\n")
  }
  self.started = true
  self.target.write("--\{self.boundary}\r\n")
  for name, value in headers {
    self.target.write("\{name}: \{value}\r\n")
  }
  self.target.write("\r\n")
  callback(self.target)
}

///|
/// Stream a reader's remaining bytes as one part, leaving both streams open.
pub async fn Writer::write_reader(
  self : Self,
  headers~ : @http.Headers,
  source : &@io.Reader,
) -> Unit {
  self.write_part(headers~, target => target.write_reader(source))
}

///|
/// Write the closing delimiter without closing the underlying writer.
/// Repeated calls have no effect.
pub async fn Writer::finish(self : Self) -> Unit {
  guard !self.finished else { return }
  self.finished = true
  if self.started {
    self.target.write("\r\n")
  }
  self.target.write("--\{self.boundary}--\r\n")
}

///|
// RFC 2046 section 5.1.1: 1..70 bchars, with no trailing space.
fn validate_boundary(boundary : String) -> Unit raise MultipartError {
  guard boundary.length() > 0 && boundary.length() <= 70 else {
    raise MultipartError("multipart boundary must contain 1 to 70 characters")
  }
  for ch in boundary {
    match ch {
      'a'..='z'
      | 'A'..='Z'
      | '0'..='9'
      | '\''
      | '('
      | ')'
      | '+'
      | '_'
      | ','
      | '-'
      | '.'
      | '/'
      | ':'
      | '='
      | '?'
      | ' ' => ()
      _ => raise MultipartError("invalid character in multipart boundary")
    }
  }
  if boundary.has_suffix(" ") {
    raise MultipartError("multipart boundary must not end in a space")
  }
}
