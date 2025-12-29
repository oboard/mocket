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

///|
fn find_boundary(
  bytes : BytesView,
  boundary : BytesView,
  start_index : Int,
) -> Int {
  let len = bytes.length()
  let boundary_len = boundary.length()
  if start_index + boundary_len > len {
    return -1
  }
  for i = start_index; i <= len - boundary_len; i = i + 1 {
    let mut match_found = true
    for j = 0; j < boundary_len; j = j + 1 {
      if bytes[i + j] != boundary[j] {
        match_found = false
        break
      }
    }
    if match_found {
      return i
    }
  }
  -1
}

///|
pub fn parse_multipart(
  bytes : BytesView,
  boundary : String,
) -> Map[String, MultipartFormValue] {
  let res = Map::new()
  let boundary_bytes = @encoding/utf8.encode("--" + boundary)
  let boundary_len = boundary_bytes.length()
  let len = bytes.length()
  let mut start = 0
  // Find first boundary
  let first_boundary = find_boundary(bytes, boundary_bytes[:], start)
  if first_boundary == -1 {
    return res
  }
  start = first_boundary + boundary_len
  while start < len {
    // Check for end boundary "--"
    if start + 2 <= len && bytes[start] == b'-' && bytes[start + 1] == b'-' {
      break
    }

    // Skip CRLF after boundary
    if start + 2 <= len && bytes[start] == b'\r' && bytes[start + 1] == b'\n' {
      start = start + 2
    } else {
      // Malformed or unexpected char, try to find next boundary
      let next = find_boundary(bytes, boundary_bytes[:], start)
      if next == -1 {
        break
      }
      start = next + boundary_len
      continue
    }

    // Find next boundary
    let next_boundary = find_boundary(bytes, boundary_bytes[:], start)
    if next_boundary == -1 {
      break
    }

    // Part content is between start and next_boundary - 2 (CRLF)
    let part_end = next_boundary - 2
    if part_end < start {
      // Should not happen if format is correct
      break
    }
    let part_bytes = bytes[start:part_end]
    parse_multipart_part(part_bytes, res)
    start = next_boundary + boundary_len
  }
  res
}

///|
fn parse_multipart_part(
  part : BytesView,
  res : Map[String, MultipartFormValue],
) -> Unit {
  // Find double CRLF separating headers from body
  let len = part.length()
  let mut body_start = -1
  for i = 0; i < len - 3; i = i + 1 {
    if part[i] == b'\r' &&
      part[i + 1] == b'\n' &&
      part[i + 2] == b'\r' &&
      part[i + 3] == b'\n' {
      body_start = i + 4
      break
    }
  }
  if body_start == -1 {
    return
  }
  let headers_bytes = part[0:body_start - 4]
  let body_bytes = part[body_start:len]
  let headers_str = @encoding/utf8.decode(headers_bytes) catch { _ => return }
  let headers = headers_str.split("\r\n")
  let mut name = ""
  let mut filename : String? = None
  let mut content_type : String? = None
  for header in headers {
    let parts = header.split(":").to_array()
    if parts.length() >= 2 {
      let key = parts[0].trim().to_lower()
      let val = parts[1].trim()
      if key == "content-disposition" {
        // form-data; name="field"; filename="file.txt"
        let directives = val.split(";").to_array()
        for i = 0; i < directives.length(); i = i + 1 {
          let directive = directives[i].trim()
          if directive.has_prefix("name=") {
            let d_str = directive.to_string()
            try {
              let substr = d_str[6:d_str.length() - 1]
              name = substr.to_string()
            } catch {
              _ => ()
            }
          } else if directive.has_prefix("filename=") {
            let d_str = directive.to_string()
            try {
              let substr = d_str[10:d_str.length() - 1]
              filename = Some(substr.to_string())
            } catch {
              _ => ()
            }
          }
        }
      } else if key == "content-type" {
        content_type = Some(val.to_string())
      }
    }
  }
  if name != "" {
    res.set(name, { filename, content_type, data: body_bytes })
  }
}
