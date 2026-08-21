///|
fn is_tchar(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '!' ||
  c == '#' ||
  c == '$' ||
  c == '%' ||
  c == '&' ||
  c == '\'' ||
  c == '*' ||
  c == '+' ||
  c == '-' ||
  c == '.' ||
  c == '^' ||
  c == '_' ||
  c == '`' ||
  c == '|' ||
  c == '~'
}

///|
pub fn is_valid_header_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name {
    if !is_tchar(c) {
      return false
    }
  }
  true
}

///|
pub fn sanitize_header_value(s : String) -> String {
  if !s.contains("\r") && !s.contains("\n") {
    return s
  }
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '\r' | '\n' => ()
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
