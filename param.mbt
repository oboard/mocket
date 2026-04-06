/// Returns a route parameter value as a String, or None if not found.
///
/// ```mbt check
/// test {
///   let event = @mocket.MocketEvent::{
///     req: { http_method: "GET", url: "/", headers: {}, raw_body: b"" },
///     res: @mocket.HttpResponse::new(@mocket.OK),
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
