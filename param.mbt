///|
/// Returns a route parameter value as a String, or None if not found.
///
/// The value is NOT URL-decoded — it's returned exactly as it appeared in the URL.
/// For a decoded value (e.g. `hello%20world` → `hello world`), use `param_decoded()`.
pub fn MocketEvent::param(self : MocketEvent, name : String) -> String? {
  match self.params.get(name) {
    Some(v) => Some(v.to_string())
    None => None
  }
}

///|
/// Returns a URL-decoded route parameter value, or None if not found.
///
/// For example, if the URL is `/search/hello%20world` and the route is
/// `/search/:query`, this returns `Some("hello world")`.
pub fn MocketEvent::param_decoded(self : MocketEvent, name : String) -> String? {
  match self.params.get(name) {
    Some(v) => Some(@mhttp.url_decode(@utf8.encode(v.to_string())[:]))
    None => None
  }
}

///|
/// Returns a route parameter parsed as an Int, or None if not found or not a valid integer.
pub fn MocketEvent::param_int(self : MocketEvent, name : String) -> Int? {
  match self.params.get(name) {
    Some(v) =>
      try @string.parse_int(v) catch {
        _ => None
      } noraise {
        n => Some(n)
      }
    None => None
  }
}

///|
/// Returns a route parameter parsed as an Int64, or None if not found or not valid.
pub fn MocketEvent::param_int64(self : MocketEvent, name : String) -> Int64? {
  match self.params.get(name) {
    Some(v) =>
      try @string.parse_int64(v) catch {
        _ => None
      } noraise {
        n => Some(n)
      }
    None => None
  }
}

///|
/// Returns a route parameter as a String, or raises `HttpError(BadRequest)` if missing.
pub fn MocketEvent::require_param(
  self : MocketEvent,
  name : String,
) -> String raise {
  match self.params.get(name) {
    Some(v) => v.to_string()
    None =>
      raise HttpError::HttpError(
        BadRequest,
        "missing required parameter: \{name}",
      )
  }
}

///|
/// Returns a route parameter parsed as an Int, or raises `HttpError(BadRequest)`
/// if missing or not a valid integer.
pub fn MocketEvent::require_param_int(
  self : MocketEvent,
  name : String,
) -> Int raise {
  match self.params.get(name) {
    Some(v) =>
      @string.parse_int(v) catch {
        _ =>
          raise HttpError::HttpError(
            BadRequest,
            "parameter '\{name}' must be a valid integer, got '\{v}'",
          )
      }
    None =>
      raise HttpError::HttpError(
        BadRequest,
        "missing required parameter: \{name}",
      )
  }
}

///|
/// Returns a route parameter parsed as an Int64, or raises `HttpError(BadRequest)`
/// if missing or not a valid 64-bit integer.
pub fn MocketEvent::require_param_int64(
  self : MocketEvent,
  name : String,
) -> Int64 raise {
  match self.params.get(name) {
    Some(v) =>
      @string.parse_int64(v) catch {
        _ =>
          raise HttpError::HttpError(
            BadRequest,
            "parameter '\{name}' must be a valid integer, got '\{v}'",
          )
      }
    None =>
      raise HttpError::HttpError(
        BadRequest,
        "missing required parameter: \{name}",
      )
  }
}
