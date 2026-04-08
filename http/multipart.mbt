///|
/// A single value from a multipart form submission, containing optional filename, content type, and raw data.
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

///|
/// Parses a multipart/form-data body using the given boundary string.
///
/// Returns a map where each field name maps to an array of values — this
/// preserves repeated field names (e.g. a form with multiple `<input name="tag">`
/// entries). Use `.get(name)` to retrieve all values for a field, then index
/// into the array for a specific one.
pub fn parse_multipart(
  bytes : BytesView,
  boundary : String,
) -> Map[String, Array[MultipartFormValue]] {
  let res : Map[String, Array[MultipartFormValue]] = {}
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

/// Parses a single `name="value"` or `name=value` directive from a
/// Content-Disposition header. Handles both quoted and unquoted values.

///|
fn parse_disposition_value(directive : String, key : String) -> String? {
  let prefix = key + "="
  if !directive.has_prefix(prefix) {
    return None
  }
  let rest = directive[prefix.length():]
  // Quoted value
  if rest.length() >= 2 &&
    rest.has_prefix("\"") &&
    rest.view().to_string().has_suffix("\"") {
    Some(rest[1:rest.length() - 1].to_string())
  } else {
    Some(rest.to_string())
  }
}

///|
fn parse_multipart_part(
  part : BytesView,
  res : Map[String, Array[MultipartFormValue]],
) -> Unit {
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
    let parts = header.split(":").to_array()
    if parts.length() >= 2 {
      let key = parts[0].trim().to_lower()
      let val = parts[1].trim()
      if key == "content-disposition" {
        let directives = val.split(";").to_array()
        for directive in directives {
          let directive = directive.trim().to_string()
          match parse_disposition_value(directive, "name") {
            Some(n) => name = n
            None => ()
          }
          match parse_disposition_value(directive, "filename") {
            Some(f) => filename = Some(f)
            None => ()
          }
        }
      } else if key == "content-type" {
        content_type = Some(val.to_string())
      }
    }
  }
  if name != "" {
    let value = { filename, content_type, data: body_bytes }
    match res.get(name) {
      Some(existing) => existing.push(value)
      None => res.set(name, [value])
    }
  }
}

///|
/// Returns the first value for a given field name, or `None` if not present.
/// Convenience helper for forms where each field is known to have a single value.
pub fn first_multipart_value(
  form : Map[String, Array[MultipartFormValue]],
  name : String,
) -> MultipartFormValue? {
  match form.get(name) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}
