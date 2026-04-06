///|
/// The event passed to each HTTP handler, bundling the request, response, and route parameters.
pub(all) struct MocketEvent {
  req : HttpRequest
  res : HttpResponse
  params : Map[String, StringView]
}

///|
/// Parses the request body as JSON and deserializes into type `T`.
/// Shorthand for `event.req.json()`.
pub fn[T : @json.FromJson] MocketEvent::json(self : MocketEvent) -> T raise {
  self.req.json()
}

///|
/// Tries to parse the request body as JSON, returning `Ok(T)` on success
/// or `Err(message)` on failure. Shorthand for `event.req.try_json()`.
pub fn[T : @json.FromJson] MocketEvent::try_json(
  self : MocketEvent,
) -> Result[T, String] {
  self.req.try_json()
}
