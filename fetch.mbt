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
} derive(Eq)

///|
pub impl Show for HttpMethod with output(self, logger) -> Unit {
  logger.write_string(
    match self {
      GET => "GET"
      POST => "POST"
      PUT => "PUT"
      PATCH => "PATCH"
      DELETE => "DELETE"
      HEAD => "HEAD"
      OPTIONS => "OPTIONS"
      TRACE => "TRACE"
      CONNECT => "CONNECT"
    },
  )
}

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(Eq)

///|
pub impl Show for FetchCredentials with output(self, logger) -> Unit {
  logger.write_string(
    match self {
      Omit => "omit"
      SameOrigin => "same-origin"
      Include => "include"
    },
  )
}

///|
pub(all) enum FetchMode {
  Cors
  NoCors
  SameOrigin
  Navigate
} derive(Eq)

///|
pub impl Show for FetchMode with output(self, logger) -> Unit {
  logger.write_string(
    match self {
      Cors => "cors"
      NoCors => "no-cors"
      SameOrigin => "same-origin"
      Navigate => "navigate"
    },
  )
}

///|
pub suberror FetchError {
  RequestFailed(String)
}

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
