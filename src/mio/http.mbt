///|
pub type! IOError  derive(Show)

///|
pub type! NetworkError  derive(Show)

///|
pub type! ExecError  derive(Show)

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
}

///|
pub(all) enum FetchMode {
  CORS
  NoCORS
  SameOrigin
  Navigate
}

///|
struct FetchResponse {
  status : Int
  statusText : String
  headers : Map[String, String]
  data : String
} derive(ToJson, Show, Eq)

///|
pub struct HttpResponse {
  id : Int
  mut statusCode : Int
  mut headers : Json
} derive(ToJson, Show, Eq)

///|
pub(all) enum HttpMethod {
  GET
  POST
  PUT
  DELETE
  PATCH
  OPTIONS
  HEAD
  CONNECT
  TRACE
} derive(ToJson, Show, Eq)

///|
pub(all) struct HttpRequest {
  method : HttpMethod
  url : String?
  path : String
  query : String?
  body : Json?
} derive(ToJson, Show, Eq)

///|
pub fn request(_fun : (HttpRequest, HttpResponse) -> Unit!Error) -> Unit!Error {
  fail!("Invalid backend")
}

///|
pub fn listen(_port : Int) -> Unit!Error {
  fail!("Invalid backend")
}

///|
pub fn handle(_reqMethod : String, _mapping : String) -> Unit {

}

///|
pub fn writeHead(self : HttpResponse, statusCode : Int, headers : Json) -> Unit {
  // (binding.send)("http.writeHead", [Number(self.id), statusCode, headers])
  self.statusCode = statusCode
  self.headers = headers
}

///|
pub fn end(self : HttpResponse, _body : Json) -> Unit {

}

///|
pub async fn fetch(
  _url : String,
  _reqMethod? : String,
  _body? : String,
  _headers? : Map[String, String],
  _credentials? : FetchCredentials,
  _mode? : FetchMode
) -> FetchResponse!NetworkError {
  raise NetworkError
}
