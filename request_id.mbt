/// Global counter for generating unique request IDs.

///|
let request_id_counter : Ref[Int64] = Ref::new(0L)

/// Returns a middleware that assigns a unique `X-Request-Id` header to every
/// request and response.
///
/// If the incoming request already has an `X-Request-Id` header, that value
/// is preserved (useful for distributed tracing). Otherwise, a new ID is
/// generated using an incrementing counter.
///
/// The request ID is also accessible in handlers via `event.request_id()`.
///
/// ```
/// let app = @crescent.Mocket::new()
/// app.use_middleware(@crescent.request_id())
/// app.get("/", event => {
///   let id = event.request_id()
///   "Request ID: \{id}"
/// })
/// ```

///|
pub fn request_id() -> Middleware {
  async fn(event, next) noraise {
    let id = match event.req.get_header("X-Request-Id") {
      Some(existing) => existing
      None => {
        request_id_counter.val += 1L
        "req-\{request_id_counter.val}"
      }
    }
    // Set on request headers so handlers can access via event.request_id()
    event.req.headers.set("X-Request-Id", id)
    let res = next()
    // Set on response so clients can correlate
    event.res.headers.set("X-Request-Id", id)
    res
  }
}

/// Returns the request ID for this event.
///
/// Requires the `request_id()` middleware to be registered.
/// Returns `None` if the middleware is not active.

///|
pub fn MocketEvent::request_id(self : MocketEvent) -> String? {
  self.req.get_header("X-Request-Id")
}
