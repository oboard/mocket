///|
/// Input and buffer shared by Reader and its parts.
priv struct ReaderState {
  /// Stream containing the multipart message.
  source : &@io.Reader
  /// `\r\n--` followed by the boundary string.
  delimiter : Bytes
  /// Buffered input. Unread bytes start at `cursor`.
  mut pending : Bytes
  /// Position of the next unread byte in `pending`.
  mut cursor : Int
  /// Number of body bytes at `cursor` that can be returned without another scan.
  mut ready : Int
  /// The source has no more bytes, though buffered bytes may remain.
  mut eof : Bool
  /// The closing boundary has been read. There are no more parts.
  mut finished : Bool
}

///|
/// Retain only unread input when a delimiter/header spans source reads.
async fn ReaderState::ensure(self : Self, length : Int) -> Bool {
  while self.pending.length() - self.cursor < length && !self.eof {
    if self.source.read_some(max_len=8192) is Some(chunk) {
      let remaining = self.pending.length() - self.cursor
      if remaining == 0 {
        self.pending = chunk
      } else {
        let pending = FixedArray::make(remaining + chunk.length(), b'\x00')
        pending.blit_from_bytesview(0, self.pending[self.cursor:])
        pending.blit_from_bytesview(remaining, chunk)
        // This array is never modified after becoming Bytes.
        self.pending = pending.unsafe_reinterpret_as_bytes()
      }
      self.cursor = 0
    } else {
      self.eof = true
    }
  }
  self.pending.length() - self.cursor >= length
}

///|
/// Read a part's headers through the blank line before its body.
async fn ReaderState::read_headers(self : Self) -> @http.Headers {
  let headers : @http.Headers = Map([])
  let mut previous : @http.CaseInsensitiveString? = None
  for ;; {
    let bytes = self.read_header_line()
    if bytes.is_empty() {
      break
    }
    let line = @utf8.decode(bytes, ignore_bom=false) catch {
      _ => raise MultipartError("Invalid UTF-8 in multipart header")
    }
    if line is [' ' | '\t', ..] {
      guard previous is Some(key) else {
        raise MultipartError("Multipart header continuation without a field")
      }
      validate_header(key.0, line)
      headers[key] = headers[key] + line
    } else {
      if previous is Some(key) {
        headers[key] = headers[key].trim_end(chars=" \t").to_owned()
      }
      guard line.split_once(":") is Some((name, value)) else {
        raise MultipartError("Invalid multipart header")
      }
      let name = name.to_owned()
      let value = value.trim_start(chars=" \t").to_owned()
      validate_header(name, value)
      let key = @http.CaseInsensitiveString(name)
      headers[key] = if headers.get(key) is Some(old) {
        "\{old},\{value}"
      } else {
        value
      }
      previous = Some(key)
    }
  }
  if previous is Some(key) {
    headers[key] = headers[key].trim_end(chars=" \t").to_owned()
  }
  headers
}

///|
async fn ReaderState::read_header_line(self : Self) -> BytesView {
  for searched = 0 {
    if self.pending[self.cursor + searched:].find(b"\r\n") is Some(index) {
      let end = self.cursor + searched + index
      let line = self.pending[self.cursor:end]
      self.cursor = end + 2
      return line
    }
    let length = self.pending.length() - self.cursor
    guard self.ensure(length + 1) else {
      raise MultipartError("Unexpected EOF in multipart headers")
    }
    continue if length == 0 { 0 } else { length - 1 }
  }
}

///|
/// The delimiter prefix has matched at cursor. Check its suffix before
/// consuming it: a prefix followed by other bytes remains body data.
async fn ReaderState::consume_boundary(self : Self, end : Int) -> Bool {
  guard self.ensure(end + 1) else {
    raise MultipartError("Unexpected EOF in multipart boundary")
  }
  let closing = if self.pending[self.cursor + end] == b'-' {
    if self.ensure(end + 2) && self.pending[self.cursor + end + 1] == b'-' {
      true
    } else {
      return false
    }
  } else if self.pending[self.cursor + end] is (b' ' | b'\t' | b'\r' | b'\n') {
    false
  } else {
    return false
  }
  self.cursor += end + (if closing { 2 } else { 0 })
  // After recognizing a delimiter, discard transport padding incrementally.
  // Its length must not make the body buffer grow with the input.
  while self.ensure(1) && self.pending[self.cursor] is (b' ' | b'\t') {
    self.cursor += 1
  }
  if closing && self.eof && self.cursor == self.pending.length() {
    self.finished = true
    return true
  }
  guard self.ensure(2) && self.pending[self.cursor:self.cursor + 2] == b"\r\n" else {
    raise MultipartError("Invalid multipart boundary line")
  }
  self.cursor += 2
  self.finished = closing
  true
}

///|
/// Find body bytes and record their count in `ready`.
/// Return false after consuming the next boundary.
async fn ReaderState::scan_body(self : Self) -> Bool {
  for ;; {
    if self.ready > 0 {
      return true
    }
    let available = self.pending[self.cursor:]
    self.ready = if available.find(self.delimiter) is Some(index) {
      if index == 0 {
        if self.consume_boundary(self.delimiter.length()) {
          return false
        }
        self.delimiter.length()
      } else {
        index
      }
    } else {
      // A partial delimiter fits in this short tail. Since the boundary cannot
      // contain CR, only the last CR can begin a matching prefix.
      let start = @cmp.maximum(
        0,
        available.length() - self.delimiter.length() + 1,
      )
      if available[start:].rev_find(b"\r") is Some(index) &&
        self.delimiter.has_prefix(available[start + index:]) {
        start + index
      } else {
        available.length()
      }
    }
    if self.ready == 0 {
      guard self.ensure(self.pending.length() - self.cursor + 1) else {
        raise MultipartError("Unexpected EOF before multipart boundary")
      }
    }
  }
}

///|
/// Parses an unfolded MIME field value, such as Content-Type or Content-Disposition.
/// The main value is a token or type/subtype; parameter names are case-insensitive.
/// Main values and parameter values retain their case. Comments are ignored and
/// quoted pairs are unescaped; percent escapes and extended parameters stay raw.
/// Grammar: RFC 2045 §5.1 and RFC 2183 §2.
pub fn parse_header_value(
  value : String,
) -> (String, Map[@http.CaseInsensitiveString, String]) raise MultipartError {
  validate_header_value(value)
  let (kind, rest) = header_token(header_space(value))
  let rest = header_space(rest)
  let (kind, rest) = if rest is ['/', .. rest] {
    let (subtype, rest) = header_token(header_space(rest))
    ("\{kind}/\{subtype}", rest)
  } else {
    (kind, rest)
  }
  let parameters : Map[@http.CaseInsensitiveString, String] = Map([])
  for rest = rest {
    let rest = header_space(rest)
    guard rest != "" else { break (kind, parameters) }
    guard rest is [';', .. rest] else {
      raise MultipartError("expected ';' before MIME parameter")
    }
    let (attribute, rest) = header_token(header_space(rest))
    guard header_space(rest) is ['=', .. rest] else {
      raise MultipartError("expected '=' in MIME parameter")
    }
    let rest = header_space(rest)
    let (value, rest) = if rest is ['"', .. rest] {
      let result = StringBuilder()
      let rest = for rest = rest {
        match rest {
          ['"', .. tail] => break tail
          ['\\', c, .. tail] => {
            result.write_char(c)
            continue tail
          }
          [c, .. tail] if c != '\\' => {
            result.write_char(c)
            continue tail
          }
          _ => raise MultipartError("invalid quoted MIME parameter")
        }
      }
      (result.to_string(), rest)
    } else {
      header_token(rest)
    }
    let attribute = @http.CaseInsensitiveString(attribute)
    guard !parameters.contains(attribute) else {
      raise MultipartError("duplicate MIME parameter")
    }
    parameters[attribute] = value
    continue rest
  }
}

///|
fn header_token(
  source : StringView,
) -> (String, StringView) raise MultipartError {
  let end = source
    .find_by(c => !c.is_ascii_graphic() || "()<>@,;:\\\"/[]?=".contains_char(c))
    .unwrap_or(source.length())
  let (token, rest) = source.split_at(end)
  guard token != "" else { raise MultipartError("expected a MIME token") }
  (token.to_owned(), rest)
}

///|
// RFC 2045 §5.1 permits RFC 822 comments between lexical tokens, including
// nested comments and quoted pairs. Input field values are already unfolded.
fn header_space(source : StringView) -> StringView raise MultipartError {
  for rest = source, depth = 0 {
    match rest {
      ['(', .. tail] => continue tail, depth + 1
      [')', .. tail] if depth > 0 => continue tail, depth - 1
      ['\\', _, .. tail] if depth > 0 => continue tail, depth
      [' ' | '\t', .. tail] => continue tail, depth
      [_, .. tail] if depth > 0 => continue tail, depth
      _ if depth > 0 => raise MultipartError("unterminated MIME comment")
      _ => break rest
    }
  }
}

///|
// RFC 5322 section 3.6.8 field-name syntax; RFC 7578 permits UTF-8 metadata.
fn validate_header(name : String, value : String) -> Unit raise MultipartError {
  guard !name.is_empty() else {
    raise MultipartError("multipart header name is empty")
  }
  for ch in name {
    guard ch >= '!' && ch <= '~' && ch != ':' else {
      raise MultipartError("invalid multipart header name")
    }
  }
  validate_header_value(value)
}

///|
fn validate_header_value(value : String) -> Unit raise MultipartError {
  for ch in value {
    guard ch == '\t' || (ch >= ' ' && ch != '\u007f') else {
      raise MultipartError("invalid control character in multipart header")
    }
  }
}
