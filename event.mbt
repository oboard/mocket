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
