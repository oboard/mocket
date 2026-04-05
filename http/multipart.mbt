/// A single value from a multipart form submission, containing optional filename, content type, and raw data.

///|
pub(all) struct MultipartFormValue {
  filename : String?
  content_type : String?
  data : BytesView
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

/// Parses a multipart/form-data body using the given boundary string into a map of form values.

///|
pub fn parse_multipart(
  bytes : BytesView,
  boundary : String,
) -> Map[String, MultipartFormValue] {
  let res = Map::new()
  let boundary_bytes = @utf8.encode("--" + boundary)
  let boundary_len = boundary_bytes.length()
  let len = bytes.length()
  let mut start = 0
  let first_boundary = find_boundary(bytes, boundary_bytes[:], start)
  if first_boundary == -1 {
    return res
  }
  start = first_boundary + boundary_len
  while start < len {
    if start + 2 <= len && bytes[start] == b'-' && bytes[start + 1] == b'-' {
      break
    }
    if start + 2 <= len && bytes[start] == b'\r' && bytes[start + 1] == b'\n' {
      start = start + 2
    } else {
      let next = find_boundary(bytes, boundary_bytes[:], start)
      if next == -1 {
        break
      }
      start = next + boundary_len
      continue
    }
    let next_boundary = find_boundary(bytes, boundary_bytes[:], start)
    if next_boundary == -1 {
      break
    }
    let part_end = next_boundary - 2
    if part_end < start {
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
  let headers_str = @utf8.decode(headers_bytes) catch { _ => return }
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
        let directives = val.split(";").to_array()
        for i = 0; i < directives.length(); i = i + 1 {
          let directive = directives[i].trim()
          if directive.has_prefix("name=") {
            let d_str = directive.to_string()
            let substr = d_str[6:d_str.length() - 1]
            name = substr.to_string()
          } else if directive.has_prefix("filename=") {
            let d_str = directive.to_string()
            let substr = d_str[10:d_str.length() - 1]
            filename = Some(substr.to_string())
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
