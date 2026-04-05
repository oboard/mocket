/// Extracts the path component from an HTTP request target by stripping the
/// query string and fragment portions.

///|
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
  request_target[:end].to_string()
}

/// Extracts the query string from an HTTP request target, excluding the leading
/// `?` delimiter. Returns `None` if no query string is present.

///|
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

/// Returns `true` if the request path falls within the given scope path. The
/// root scope `"/"` matches all paths; otherwise the request path must equal or
/// be a sub-path of the scope (separated by `'/'`).

///|
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
