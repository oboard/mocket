///|
pub(all) enum HttpMethod {
  GET
  POST
  PUT
  PATCH
  DELETE
  HEAD
  OPTIONS
  TRACE
  CONNECT
} derive(Eq, Debug)

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(Eq, Debug)

///|
pub fn FetchCredentials::to_string(self : FetchCredentials) -> String {
  match self {
    Omit => "omit"
    SameOrigin => "same-origin"
    Include => "include"
  }
}

///|
pub(all) enum FetchMode {
  Cors
  NoCors
  SameOrigin
  Navigate
} derive(Eq, Debug)

///|
pub fn FetchMode::to_string(self : FetchMode) -> String {
  match self {
    Cors => "cors"
    NoCors => "no-cors"
    SameOrigin => "same-origin"
    Navigate => "navigate"
  }
}

///|
pub suberror FetchError {
  RequestFailed(String)
} derive(Debug)

///|
fn copy_headers(headers : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = {}
  headers.each(fn(k, v) { out.set(k, v) })
  out
}
