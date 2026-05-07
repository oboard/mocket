///|

///|
pub suberror RequestError {
  InvalidHttpMethod(String)
}

///|
fn parse_http_method(http_method : String) -> @mocket.HttpMethod raise Error {
  match http_method.to_upper() {
    "ACL" => ACL
    "BIND" => BIND
    "CHECKIN" => CHECKIN
    "CHECKOUT" => CHECKOUT
    "COPY" => COPY
    "DELETE" => DELETE
    "GET" => GET
    "HEAD" => HEAD
    "LABEL" => LABEL
    "LINK" => LINK
    "LOCK" => LOCK
    "MERGE" => MERGE
    "MKACTIVITY" => MKACTIVITY
    "MKCALENDAR" => MKCALENDAR
    "MKCOL" => MKCOL
    "MKREDIRECTREF" => MKREDIRECTREF
    "MKWORKSPACE" => MKWORKSPACE
    "MOVE" => MOVE
    "OPTIONS" => OPTIONS
    "ORDERPATCH" => ORDERPATCH
    "PATCH" => PATCH
    "POST" => POST
    "PRI" => PRI
    "PROPFIND" => PROPFIND
    "PROPPATCH" => PROPPATCH
    "PUT" => PUT
    "QUERY" => QUERY
    "REBIND" => REBIND
    "REPORT" => REPORT
    "SEARCH" => SEARCH
    "TRACE" => TRACE
    "UNBIND" => UNBIND
    "UNCHECKOUT" => UNCHECKOUT
    "UNLINK" => UNLINK
    "UNLOCK" => UNLOCK
    "UPDATE" => UPDATE
    "UPDATEREDIRECTREF" => UPDATEREDIRECTREF
    "VERSION-CONTROL" => VERSION_CONTROL
    _ => raise RequestError::InvalidHttpMethod(http_method)
  }
}

///|
pub async fn request(
  req : @mocket.HttpRequest,
) -> @mocket.HttpResponse raise Error {
  let http_method = parse_http_method(req.http_method)
  let headers : Map[String, String] = {}
  req.headers.each((k, v) => headers.set(k.to_owned(), v.to_owned()))
  if req.raw_body.length() == 0 {
    @mocket.fetch(req.url, http_method, headers~)
  } else {
    let data = req.raw_body
    @mocket.fetch(req.url, http_method, data~, headers~)
  }
}

///|
pub async fn get(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, GET, data?, headers?, credentials?, mode?)
}

///|
pub async fn delete(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, DELETE, data?, headers?, credentials?, mode?)
}

///|
pub async fn head(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, HEAD, data?, headers?, credentials?, mode?)
}

///|
pub async fn options(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, OPTIONS, data?, headers?, credentials?, mode?)
}

///|
pub async fn trace(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, TRACE, data?, headers?, credentials?, mode?)
}

///|
pub async fn connect(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, CONNECT, data?, headers?, credentials?, mode?)
}

///|
pub async fn post(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, POST, data?, headers?, credentials?, mode?)
}

///|
pub async fn put(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, PUT, data?, headers?, credentials?, mode?)
}

///|
pub async fn patch(
  url : String,
  data? : &@mocket.Responder,
  headers? : Map[String, String],
  credentials? : @mocket.FetchCredentials,
  mode? : @mocket.FetchMode,
) -> @mocket.HttpResponse raise Error {
  @mocket.fetch(url, PATCH, data?, headers?, credentials?, mode?)
}
