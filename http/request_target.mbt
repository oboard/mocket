///|
/// Extracts the path component from an HTTP request target by stripping the
/// query string and fragment portions.
pub fn request_target_path(request_target : String) -> String {
  let mut end = request_target.length()
  match request_target.find("?") {
    Some(index) => if index < end { end = index }
    None => ()
  }
  match request_target.find("#") {
    Some(index) => if index < end { end = index }
    None => ()
  }
  // Avoid allocation when the path is the entire string (common case: no query/fragment)
  if end == request_target.length() {
    if request_target.contains("//") {
      return normalize_path(request_target)
    }
    return request_target
  }
  normalize_path(request_target[:end].to_string())
}

///|
/// Normalizes a URL path by collapsing consecutive slashes into single slashes.
/// Preserves the leading slash if present.
pub fn normalize_path(path : String) -> String {
  if !path.contains("//") {
    return path
  }
  let buf = StringBuilder::new()
  let mut prev_slash = false
  for c in path {
    if c == '/' {
      if !prev_slash {
        buf.write_char('/')
      }
      prev_slash = true
    } else {
      buf.write_char(c)
      prev_slash = false
    }
  }
  buf.to_string()
}

///|
/// Extracts the query string from an HTTP request target, excluding the leading
/// `?` delimiter. Returns `None` if no query string is present.
pub fn request_target_query_string(request_target : String) -> String? {
  match request_target.find("?") {
    Some(query_start) => {
      let mut end = request_target.length()
      match request_target.find("#") {
        Some(fragment_start) if fragment_start > query_start =>
          end = fragment_start
        _ => ()
      }
      Some(request_target[query_start + 1:end].to_string())
    }
    None => None
  }
}

///|
/// Returns `true` if the request path falls within the given scope path. The
/// root scope `"/"` matches all paths; otherwise the request path must equal or
/// be a sub-path of the scope (separated by `'/'`).
pub fn path_scope_matches(scope_path : String, request_path : String) -> Bool {
  if scope_path == "/" {
    true
  } else if !request_path.has_prefix(scope_path) {
    false
  } else if request_path.length() == scope_path.length() {
    true
  } else {
    request_path[scope_path.length()] == '/'
  }
}
