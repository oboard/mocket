/// Returns a route parameter value as a String, or None if not found.
///
/// ```mbt check
/// test {
///   let event = @crescent.MocketEvent::{
///     req: @crescent.HttpRequest::new(@crescent.Get, "/", {}, raw_body=b""),
///     res: @crescent.HttpResponse::new(@crescent.OK),
///     params: { "id": "42" },
///   }
///   inspect(event.param("id"), content="Some(\"42\")")
///   inspect(event.param("missing"), content="None")
/// }
/// ```

///|
pub fn MocketEvent::param(self : MocketEvent, name : String) -> String? {
  match self.params.get(name) {
    Some(v) => Some(v.to_string())
    None => None
  }
}

/// Returns a route parameter parsed as an Int, or None if not found or not a valid integer.

///|
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

/// Returns a route parameter parsed as an Int64, or None if not found or not valid.

///|
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

/// Returns a route parameter as a String, or raises `HttpError(BadRequest)` if missing.
///
/// This is the recommended way for AI agents to extract required route parameters,
/// as it automatically produces a clear 400 error for missing parameters.
///
/// ```
/// // Instead of:
/// //   let name = match event.param("name") { Some(n) => n, None => raise ... }
/// // Write:
/// let name = event.require_param("name")
/// ```

///|
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

/// Returns a route parameter parsed as an Int, or raises `HttpError(BadRequest)`
/// if missing or not a valid integer.
///
/// This is the recommended way to extract typed route parameters in handlers
/// registered with `get`, `post`, etc.
///
/// ```
/// app.get("/users/:id", event => {
///   let id = event.require_param_int("id")
///   HttpResponse::ok().json_value(find_user(id))
/// })
/// ```

///|
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

/// Returns a route parameter parsed as an Int64, or raises `HttpError(BadRequest)`
/// if missing or not a valid 64-bit integer.

///|
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
