/// The event passed to each HTTP handler, bundling the request, response, and route parameters.
///
/// - `req` holds the incoming HTTP request.
/// - `res` holds the outgoing HTTP response being constructed.
/// - `params` holds named parameters extracted from the matched route pattern.

///|
pub(all) struct MocketEvent {
  req : HttpRequest
  res : HttpResponse
  params : Map[String, StringView]
}

/// Parses the request body as JSON and deserializes into type `T`.
///
/// Shorthand for `event.req.json()`. This is the recommended way to extract
/// typed data from request bodies in handlers.
///
/// ```
/// struct CreateUser { name : String } derive(FromJson)
///
/// app.post("/users", event => {
///   let user : CreateUser = event.json()
///   HttpResponse::created().json_value(user)
/// })
/// ```

///|
pub fn[T : @json.FromJson] MocketEvent::json(self : MocketEvent) -> T raise {
  self.req.json()
}

/// Tries to parse the request body as JSON, returning `Ok(T)` on success
/// or `Err(message)` on failure. Shorthand for `event.req.try_json()`.
///
/// Use this when you want custom error handling instead of automatic error mapping.

///|
pub fn[T : @json.FromJson] MocketEvent::try_json(
  self : MocketEvent,
) -> Result[T, String] {
  self.req.try_json()
}
