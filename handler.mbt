/// The async handler type for HTTP route callbacks.
///
/// Receives a `MocketEvent` and returns a `Responder`.

///|
pub type HttpHandler = async (MocketEvent) -> &Responder noraise
