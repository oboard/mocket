///|
/// The async handler type for HTTP route callbacks.
pub type HttpHandler = async (MocketEvent) -> &Responder noraise
