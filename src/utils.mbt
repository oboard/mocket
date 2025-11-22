///|
fn hex_digit(b : Byte) -> Int? {
  if b >= b'0' && b <= b'9' {
    Some(b.to_int() - b'0'.to_int())
  } else if b >= b'a' && b <= b'f' {
    Some(b.to_int() - b'a'.to_int() + 10)
  } else if b >= b'A' && b <= b'F' {
    Some(b.to_int() - b'A'.to_int() + 10)
  } else {
    None
  }
}

///|
pub fn url_decode(bytes : BytesView) -> String {
  let len = bytes.length()
  let res = Array::make(len, b'\x00')
  let mut w = 0
  let mut r = 0
  while r < len {
    let b = bytes[r]
    if b == b'+' {
      res[w] = b' '
      w = w + 1
      r = r + 1
    } else if b == b'%' && r + 2 < len {
      match (hex_digit(bytes[r + 1]), hex_digit(bytes[r + 2])) {
        (Some(h1), Some(h2)) => {
          res[w] = (h1 * 16 + h2).to_byte()
          w = w + 1
          r = r + 3
        }
        _ => {
          res[w] = b'%'
          w = w + 1
          r = r + 1
        }
      }
    } else {
      res[w] = b
      w = w + 1
      r = r + 1
    }
  }
  let final_bytes = Bytes::from_array(res)
  let view = final_bytes[0:w]
  @encoding/utf8.decode(view) catch {
    _ => ""
  }
}

///|
pub fn parse_form_data(bytes : BytesView) -> Map[String, String] {
  let res = Map::new()
  if bytes.length() == 0 {
    return res
  }

  // Split by '&'
  let mut start = 0
  let len = bytes.length()
  for i = 0; i < len; i = i + 1 {
    if bytes[i] == b'&' {
      let part = bytes[start:i]
      parse_kv(part, res)
      start = i + 1
    }
  }
  if start < len {
    parse_kv(bytes[start:len], res)
  }
  res
}

///|
fn parse_kv(part : BytesView, map : Map[String, String]) -> Unit {
  let len = part.length()
  let mut eq_idx = -1
  for i = 0; i < len; i = i + 1 {
    if part[i] == b'=' {
      eq_idx = i
      break
    }
  }
  if eq_idx != -1 {
    let key_bytes = part[0:eq_idx]
    let val_bytes = part[eq_idx + 1:len]
    let key = url_decode(key_bytes)
    let val = url_decode(val_bytes)
    if key != "" {
      map.set(key, val)
    }
  } else {
    // No '=', treat as key with empty value? Or ignore?
    // Usually key without value.
    let key = url_decode(part)
    if key != "" {
      map.set(key, "")
    }
  }
}

///|
fn is_unreserved(b : Byte) -> Bool {
  (b >= b'A' && b <= b'Z') ||
  (b >= b'a' && b <= b'z') ||
  (b >= b'0' && b <= b'9') ||
  b == b'-' ||
  b == b'_' ||
  b == b'.' ||
  b == b'~'
}

///|
pub fn url_encode(s : String) -> String {
  let bytes = @encoding/utf8.encode(s)
  let buf = StringBuilder::new()
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i]
    if is_unreserved(b) {
      match b.to_int().to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    } else {
      buf.write_char('%')
      let hex_bytes = b"0123456789ABCDEF"
      let h1 = (b.to_int() >> 4) & 0xF
      let h2 = b.to_int() & 0xF
      match hex_bytes[h1].to_int().to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
      match hex_bytes[h2].to_int().to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    }
  }
  buf.to_string()
}

///|
pub fn form_encode(map : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  let mut first = true
  map.each(fn(k, v) {
    if not(first) {
      buf.write_char('&')
    }
    first = false
    buf.write_string(url_encode(k))
    buf.write_char('=')
    buf.write_string(url_encode(v))
  })
  buf.to_string()
}
