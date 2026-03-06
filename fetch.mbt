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
} derive(Eq, Show)

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(Eq, Show)

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
} derive(Eq, Show)

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
} derive(Show)

///|
fn copy_headers(headers : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = {}
  headers.each(fn(k, v) { out.set(k, v) })
  out
}

///|
fn prepare_fetch_payload(
  body : String?,
  data : &Responder?,
  headers : Map[String, String]?,
) -> (String?, Map[String, String]) {
  let req_headers = copy_headers(headers.unwrap_or({}))
  let req_body = match body {
    Some(raw_body) => Some(raw_body)
    None =>
      match data {
        Some(responder_data) => {
          let res = HttpResponse::new(OK)
          responder_data.options(res)
          res.headers.each(fn(k, v) {
            if req_headers.get(k.to_string()) is None {
              req_headers.set(k.to_string(), v.to_string())
            }
          })
          let body_buf = @buffer.new()
          responder_data.output(body_buf)
          Some(body_buf.to_string())
        }
        None => None
      }
  }
  (req_body, req_headers)
}
