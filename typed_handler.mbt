///|
/// Error type for handlers that want automatic HTTP error responses.
pub(all) suberror HttpError {
  HttpError(StatusCode, String)
} derive(Debug)

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

///|
/// Registers a GET handler with automatic error-to-JSON mapping.
pub fn Mocket::get(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.get_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a POST handler with automatic error-to-JSON mapping.
pub fn Mocket::post(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.post_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a PUT handler with automatic error-to-JSON mapping.
pub fn Mocket::put(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.put_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a PATCH handler with automatic error-to-JSON mapping.
pub fn Mocket::patch(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.patch_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a DELETE handler with automatic error-to-JSON mapping.
pub fn Mocket::delete(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.delete_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a HEAD handler with automatic error-to-JSON mapping.
pub fn Mocket::head(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.head_raw(path, wrap_error_handler(handler))
}

///|
/// Registers an OPTIONS handler with automatic error-to-JSON mapping.
pub fn Mocket::options(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.options_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a TRACE handler with automatic error-to-JSON mapping.
pub fn Mocket::trace(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.trace_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a CONNECT handler with automatic error-to-JSON mapping.
pub fn Mocket::connect(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.connect_raw(path, wrap_error_handler(handler))
}

///|
/// Registers a handler matching all HTTP methods with automatic error-to-JSON mapping.
pub fn Mocket::all(
  self : Mocket,
  path : String,
  handler : async (MocketEvent) -> &Responder,
) -> Unit {
  self.all_raw(path, wrap_error_handler(handler))
}
