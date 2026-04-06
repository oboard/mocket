// HttpMethod is defined in http_method.mbt

///|
/// Controls whether credentials (cookies, TLS certificates) are sent with a fetch request.
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(Eq, Debug)

///|
/// Returns the string representation of a `FetchCredentials` value for use in fetch request options.
pub fn FetchCredentials::to_string(self : FetchCredentials) -> String {
  match self {
    Omit => "omit"
    SameOrigin => "same-origin"
    Include => "include"
  }
}

///|
/// Controls the CORS mode for a fetch request.
pub(all) enum FetchMode {
  Cors
  NoCors
  SameOrigin
  Navigate
} derive(Eq, Debug)

///|
/// Returns the string representation of a `FetchMode` value for use in fetch request options.
pub fn FetchMode::to_string(self : FetchMode) -> String {
  match self {
    Cors => "cors"
    NoCors => "no-cors"
    SameOrigin => "same-origin"
    Navigate => "navigate"
  }
}

///|
/// Error type for fetch operations, wrapping a failure message.
pub suberror FetchError {
  RequestFailed(String)
} derive(Debug)

///|
fn copy_headers(headers : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = {}
  headers.each(fn(k, v) { out.set(k, v) })
  out
}
