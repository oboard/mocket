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
  @utf8.decode(view) catch {
    _ => ""
  }
}

///|
pub fn parse_form_data(bytes : BytesView) -> Map[String, String] {
  let res = Map([])
  if bytes.length() == 0 {
    return res
  }

  // Split by '&'
  let mut start = 0
  let len = bytes.length()
  for i in 0..<len {
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
// 解析 URL 查询字符串（不含 `?`）成键值对，键值会做 URL 解码。
// 与 parse_form_data 共享相同的 `&`/`=` 分割逻辑。
pub fn parse_query(query_string : StringView) -> Map[String, String] {
  let res = Map([])
  if query_string.length() == 0 {
    return res
  }
  // Split by '&'
  let mut start = 0
  let len = query_string.length()
  for i in 0..<len {
    if query_string[i] == '&' {
      let part = query_string[start:i]
      parse_kv(@utf8.encode(part)[:], res)
      start = i + 1
    }
  }
  if start < len {
    parse_kv(@utf8.encode(query_string[start:len])[:], res)
  }
  res
}

///|
fn parse_kv(part : BytesView, map : Map[String, String]) -> Unit {
  let len = part.length()
  let mut eq_idx = -1
  for i in 0..<len {
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
pub fn escape_html(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      '\'' => buf.write_string("&#x27;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
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
  let bytes = @utf8.encode(s)
  let buf = StringBuilder()
  for i in 0..<bytes.length() {
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
  let buf = StringBuilder()
  let mut first = true
  map.each(fn(k, v) {
    if !first {
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
fn boundary_at(bytes : BytesView, boundary : BytesView, index : Int) -> Bool {
  let boundary_len = boundary.length()
  let len = bytes.length()
  if index < 0 || index + boundary_len > len {
    return false
  }
  // A delimiter is valid only at the beginning of the body or immediately after
  // CRLF, and must be followed by CRLF or the closing `--` marker.
  if index != 0 &&
    (index < 2 || bytes[index - 2] != b'\r' || bytes[index - 1] != b'\n') {
    return false
  }
  if index + boundary_len + 2 > len ||
    !((
      bytes[index + boundary_len] == b'\r' &&
      bytes[index + boundary_len + 1] == b'\n'
    ) ||
    (
      bytes[index + boundary_len] == b'-' &&
      bytes[index + boundary_len + 1] == b'-'
    )) {
    return false
  }
  for j in 0..<boundary_len {
    if bytes[index + j] != boundary[j] {
      return false
    }
  }
  true
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
  for i in start_index..<=(len - boundary_len) {
    if boundary_at(bytes, boundary, i) {
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
  let res = Map([])
  let boundary_bytes = @utf8.encode("--" + boundary)
  let boundary_len = boundary_bytes.length()
  let len = bytes.length()
  let first_boundary = find_boundary(bytes, boundary_bytes[:], 0)
  if first_boundary == -1 {
    return res
  }
  let mut boundary_start = first_boundary
  while boundary_start < len {
    let after_boundary = boundary_start + boundary_len
    if after_boundary + 2 > len {
      break
    }
    if bytes[after_boundary] == b'-' && bytes[after_boundary + 1] == b'-' {
      break
    }
    if bytes[after_boundary] != b'\r' || bytes[after_boundary + 1] != b'\n' {
      break
    }
    let part_start = after_boundary + 2
    let next_boundary = find_boundary(bytes, boundary_bytes[:], part_start)
    if next_boundary == -1 || next_boundary < part_start + 2 {
      break
    }
    // `find_boundary` requires the CRLF before every non-initial delimiter,
    // so this excludes only the delimiter framing and preserves body bytes.
    parse_multipart_part(bytes[part_start:next_boundary - 2], res)
    boundary_start = next_boundary
  }
  res
}

///|
fn unquote_multipart_param(value : StringView) -> String {
  let value = value.trim()
  let len = value.length()
  if len >= 2 && value[0] == '"' && value[len - 1] == '"' {
    value[1:len - 1].to_owned()
  } else {
    value.to_owned()
  }
}

///|
fn parse_multipart_part(
  part : BytesView,
  res : Map[String, MultipartFormValue],
) -> Unit {
  // Find double CRLF separating headers from body
  let len = part.length()
  let mut body_start = -1
  for i in 0..<(len - 3) {
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
  let headers_str = @utf8.decode(headers_bytes) catch { _ => return }
  let headers = headers_str.split("\r\n")
  let mut name = ""
  let mut filename : String? = None
  let mut content_type : String? = None
  for header in headers {
    if header.split_once(":") is Some((header_key, header_value)) {
      let key = header_key.trim().to_lower()
      let val = header_value.trim()
      if key == "content-disposition" {
        let directives = val.split(";").to_array()
        for directive in directives {
          if directive.trim().split_once("=") is Some((param_key, param_value)) {
            let key = param_key.trim().to_lower()
            let value = unquote_multipart_param(param_value.trim())
            if key == "name" {
              name = value
            } else if key == "filename" {
              filename = Some(value)
            }
          }
        }
      } else if key == "content-type" {
        content_type = Some(val.to_owned())
      }
    }
  }
  if name != "" {
    res.set(name, { filename, content_type, data: body_bytes, })
  }
}

///|
fn append_string(bytes : Array[Byte], value : String) -> Unit {
  for byte in @utf8.encode(value) {
    bytes.push(byte)
  }
}

///|
fn sanitize_multipart_metadata(value : String) -> String {
  let result = StringBuilder()
  for char in value {
    if char != '\r' && char != '\n' {
      result.write_char(char)
    }
  }
  result.to_string()
}

///|
pub fn encode_multipart(
  m : Map[String, MultipartFormValue],
  boundary : String,
) -> Bytes {
  let bytes = []
  let boundary = sanitize_multipart_metadata(boundary)
  m.each(fn(name, v) {
    append_string(bytes, "--" + boundary + "\r\n")
    append_string(
      bytes,
      "Content-Disposition: form-data; name=\"" +
      sanitize_multipart_metadata(name) +
      "\"",
    )
    match v.filename {
      Some(filename) =>
        append_string(
          bytes,
          "; filename=\"" + sanitize_multipart_metadata(filename) + "\"",
        )
      None => ()
    }
    append_string(bytes, "\r\n")
    match v.content_type {
      Some(content_type) =>
        append_string(
          bytes,
          "Content-Type: " + sanitize_multipart_metadata(content_type) + "\r\n",
        )
      None => ()
    }
    append_string(bytes, "\r\n")
    for byte in v.data {
      bytes.push(byte)
    }
    append_string(bytes, "\r\n")
  })
  append_string(bytes, "--" + boundary + "--\r\n")
  Bytes::from_array(bytes)
}
