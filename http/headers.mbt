/// Compares two HTTP header names for equality using case-insensitive matching.

///|
fn header_name_matches(left : String, right : String) -> Bool {
  left.to_lower() == right.to_lower()
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
