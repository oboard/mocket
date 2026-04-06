///|

///|
/// Error type for invalid HTTP method strings encountered during request parsing.
pub suberror RequestError {
  InvalidHttpMethod(String)
}

///|
fn parse_http_method(http_method : String) -> @crescent.HttpMethod raise Error {
  match http_method.to_lower() {
    "get" => Get
    "post" => Post
    "put" => Put
    "patch" => Patch
    "delete" => Delete
    "head" => Head
    "options" => Options
    "trace" => Trace
    "connect" => Connect
    _ => raise RequestError::InvalidHttpMethod(http_method)
  }
}

///|
/// Sends an HTTP request using the method, URL, headers, and body from the given
/// `HttpRequest` object, and returns the response.
pub async fn request(
  req : @crescent.HttpRequest,
) -> @crescent.HttpResponse raise Error {
  let http_method = req.http_method
  let headers : Map[String, String] = {}
  req.headers.each((k, v) => headers.set(k.to_string(), v.to_string()))
  if req.raw_body.length() == 0 {
    @crescent.fetch(req.url, http_method, headers~)
  } else {
    let data = req.raw_body
    @crescent.fetch(req.url, http_method, data~, headers~)
  }
}

///|
/// Sends an HTTP GET request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn get(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Get, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP DELETE request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn delete(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Delete, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP HEAD request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn head(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Head, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP OPTIONS request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn options(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Options, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP TRACE request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn trace(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Trace, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP CONNECT request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn connect(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Connect, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP POST request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn post(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Post, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP PUT request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn put(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Put, data?, headers?, credentials?, mode?)
}

///|
/// Sends an HTTP PATCH request to the given URL with optional data, headers,
/// credentials, and mode settings.
pub async fn patch(
  url : String,
  data? : &@crescent.Responder,
  headers? : Map[String, String],
  credentials? : @crescent.FetchCredentials,
  mode? : @crescent.FetchMode,
) -> @crescent.HttpResponse raise Error {
  @crescent.fetch(url, Patch, data?, headers?, credentials?, mode?)
}
