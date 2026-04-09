///|
/// Extracts the path component from an HTTP request target.
///
/// Handles all request-target forms from RFC 7230 §5.3:
/// - origin-form: `/path?query` → returns `/path`
/// - absolute-form: `http://host/path?query` → returns `/path`
/// - authority-form: `host:port` (CONNECT only) → returns the target unchanged
/// - asterisk-form: `*` (OPTIONS only) → returns `*`
pub fn request_target_path(request_target : String) -> String {
  // Detect absolute-form (contains a scheme "://").
  // We must only strip `//` inside the path, never the scheme separator.
  let after_scheme = match request_target.find("://") {
    Some(scheme_end) => {
      // absolute-form: skip past the authority to find the path
      let authority_start = scheme_end + 3
      match request_target[authority_start:].find("/") {
        Some(rel_path_start) =>
          // Path exists — extract from the first `/` after authority
          authority_start + rel_path_start
        None =>
          // No path, default to "/"
          return "/"
      }
    }
    None => 0 // origin-form or other: start from position 0
  }
  // Now clip query/fragment from the path-portion
  let target_from_path = request_target[after_scheme:]
  let mut end = target_from_path.length()
  match target_from_path.find("?") {
    Some(index) => if index < end { end = index }
    None => ()
  }
  match target_from_path.find("#") {
    Some(index) => if index < end { end = index }
    None => ()
  }
  let path_view = target_from_path[:end]
  // Only normalize `//` within the path itself.
  let path_str = path_view.to_string()
  if path_str.contains("//") {
    normalize_path(path_str)
  } else {
    path_str
  }
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
