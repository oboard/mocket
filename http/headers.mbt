/// Compares two HTTP header names for equality using case-insensitive matching.
/// Uses character-by-character comparison to avoid String allocation from .to_lower().

///|
fn header_name_matches(left : String, right : String) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let left_view = left.view()
  let right_view = right.view()
  for i = 0; i < left.length(); i = i + 1 {
    let l = left_view.unsafe_get(i)
    let r = right_view.unsafe_get(i)
    // Fast path: exact match
    if l == r {
      continue
    }
    // ASCII case-insensitive comparison (a-z vs A-Z differ by 0x20)
    let lc = if l >= 65 && l <= 90 { l + 32 } else { l }
    let rc = if r >= 65 && r <= 90 { r + 32 } else { r }
    if lc != rc {
      return false
    }
  }
  true
}

/// Returns the original key from the headers map that matches the given header name
/// case-insensitively, or `None` if no match is found.

///|
fn find_header_key_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> String? {
  for pair in headers {
    let (key, _) = pair
    if header_name_matches(key, header_name) {
      return Some(key)
    }
  }
  None
}

/// Retrieves the value of a header by name using case-insensitive lookup, or
/// `None` if the header is not present.

///|
pub fn get_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> String? {
  match find_header_key_case_insensitive(headers, header_name) {
    Some(key) => headers.get(key)
    None => None
  }
}

/// Returns `true` if the headers map contains a header matching the given name
/// case-insensitively.

///|
pub fn has_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> Bool {
  get_header_case_insensitive(headers, header_name) is Some(_)
}

/// Sets a header value using case-insensitive key matching. If a header with the
/// same name already exists (regardless of case), the existing entry is replaced;
/// otherwise the new key-value pair is inserted.

///|
fn set_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
  value : String,
) -> Unit {
  match find_header_key_case_insensitive(headers, header_name) {
    Some(existing_key) if existing_key != header_name => {
      ignore(headers.remove(existing_key))
      headers.set(header_name, value)
    }
    Some(existing_key) => headers.set(existing_key, value)
    None => headers.set(header_name, value)
  }
}

/// Sets a header value only if no header with the same name (case-insensitive)
/// already exists in the map.

///|
pub fn set_missing_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
  value : String,
) -> Unit {
  if !has_header_case_insensitive(headers, header_name) {
    headers.set(header_name, value)
  }
}

/// Merges all headers from the source map into the target map using
/// case-insensitive key matching, overwriting existing entries on conflict.

///|
pub fn merge_headers_case_insensitive(
  target : Map[String, String],
  source : Map[String, String],
) -> Unit {
  source.each((key, value) => set_header_case_insensitive(target, key, value))
}
