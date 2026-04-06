/// Error type for handlers that want automatic HTTP error responses.
///
/// Raise `HttpError(status, message)` from a handler registered with
/// `get_json`, `post_json`, etc. to return a structured JSON error.

///|
pub(all) suberror HttpError {
  HttpError(StatusCode, String)
} derive(Debug)

/// Wraps a raising handler into a noraise HttpHandler with automatic error mapping.
///
/// Caught errors are mapped to JSON responses:
/// - `HttpError(status, msg)` → `{"error":{"status":<int>,"message":"<msg>"}}`
/// - `@json.JsonDecodeError` → 400 Bad Request
/// - Any other error → 500 Internal Server Error

///|
fn wrap_error_handler(
  handler : async (MocketEvent) -> &Responder,
) -> HttpHandler {
  event => {
    handler(event) catch {
      HttpError(status, message) => HttpResponse::error(status, message)
      @json.JsonDecodeError(_) as err =>
        HttpResponse::error(BadRequest, err.to_string())
      @json.InvalidEof as err =>
        HttpResponse::error(BadRequest, err.to_string())
      @json.InvalidChar(_) as err =>
        HttpResponse::error(BadRequest, err.to_string())
      @json.InvalidNumber(_) as err =>
        HttpResponse::error(BadRequest, err.to_string())
      @json.InvalidIdentEscape(_) as err =>
        HttpResponse::error(BadRequest, err.to_string())
      @json.DepthLimitExceeded as err =>
        HttpResponse::error(BadRequest, err.to_string())
      err => HttpResponse::error(InternalServerError, err.to_string())
    }
  }
}

/// Registers a GET handler that can raise errors. Errors are automatically
/// converted to JSON error responses.

///|
pub fn Mocket::get_json(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.get(path, wrap_error_handler(handler))
}

/// Registers a POST handler that can raise errors.

///|
pub fn Mocket::post_json(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.post(path, wrap_error_handler(handler))
}

/// Registers a PUT handler that can raise errors.

///|
pub fn Mocket::put_json(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.put(path, wrap_error_handler(handler))
}

/// Registers a PATCH handler that can raise errors.

///|
pub fn Mocket::patch_json(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.patch(path, wrap_error_handler(handler))
}

/// Registers a DELETE handler that can raise errors.

///|
pub fn Mocket::delete_json(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.delete(path, wrap_error_handler(handler))
}
