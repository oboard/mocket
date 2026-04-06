/// Error type for handlers that want automatic HTTP error responses.
///
/// Raise `HttpError(status, message)` from any handler registered with
/// `get`, `post`, etc. to return a structured JSON error.

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
/// converted to JSON error responses. This is the recommended default for
/// AI agents and most handlers.
///
/// ```
/// app.get("/users/:id", event => {
///   let id = event.require_param_int("id")
///   HttpResponse::ok().json_value(find_user(id))
/// })
/// ```

///|
pub fn Mocket::get(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.get_raw(path, wrap_error_handler(handler))
}

/// Registers a POST handler that can raise errors.

///|
pub fn Mocket::post(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.post_raw(path, wrap_error_handler(handler))
}

/// Registers a PUT handler that can raise errors.

///|
pub fn Mocket::put(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.put_raw(path, wrap_error_handler(handler))
}

/// Registers a PATCH handler that can raise errors.

///|
pub fn Mocket::patch(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.patch_raw(path, wrap_error_handler(handler))
}

/// Registers a DELETE handler that can raise errors.

///|
pub fn Mocket::delete(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.delete_raw(path, wrap_error_handler(handler))
}

/// Registers a HEAD handler that can raise errors.

///|
pub fn Mocket::head(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.head_raw(path, wrap_error_handler(handler))
}

/// Registers an OPTIONS handler that can raise errors.

///|
pub fn Mocket::options(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.options_raw(path, wrap_error_handler(handler))
}

/// Registers a TRACE handler that can raise errors.

///|
pub fn Mocket::trace(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.trace_raw(path, wrap_error_handler(handler))
}

/// Registers a CONNECT handler that can raise errors.

///|
pub fn Mocket::connect(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.connect_raw(path, wrap_error_handler(handler))
}

/// Registers a handler that matches all HTTP methods and can raise errors.

///|
pub fn Mocket::all(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.all_raw(path, wrap_error_handler(handler))
}
