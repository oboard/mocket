///|
fn http_method_to_async(http_method : HttpMethod) -> @http.RequestMethod {
  match http_method {
    GET => Get
    POST => Post
    PUT => Put
    PATCH => Patch
    DELETE => Delete
    HEAD => Head
    OPTIONS => Options
    TRACE => Trace
    CONNECT => Connect
  }
}

///|
fn split_fetch_url(url : String) -> (String, String) raise Error {
  guard url.find("://") is Some(protocol_idx) else {
    raise FetchError::RequestFailed("invalid URL: \{url}")
  }
  let rest_start = protocol_idx + 3
  let rest = url[rest_start:]
  let first_slash = rest.find("/")
  let first_query = rest.find("?")
  let split_idx = match (first_slash, first_query) {
    (Some(slash), Some(query)) => if slash < query { slash } else { query }
    (Some(slash), None) => slash
    (None, Some(query)) => query
    (None, None) => rest.length()
  }
  let origin = url[:rest_start + split_idx].to_string()
  guard origin != url[:rest_start].to_string() else {
    raise FetchError::RequestFailed("invalid URL: \{url}")
  }
  let path = if split_idx == rest.length() {
    "/"
  } else if rest[split_idx:split_idx + 1] == "?" {
    "/" + rest[split_idx:].to_string()
  } else {
    rest[split_idx:].to_string()
  }
  (origin, path)
}

///|
fn async_headers_to_views(
  headers : Map[String, String],
) -> Map[StringView, StringView] {
  let out : Map[StringView, StringView] = {}
  headers.each((key, value) => out.set(key, value))
  out
}

///|
pub async fn fetch(
  url : String,
  body? : String,
  http_method : HttpMethod,
  data? : &Responder,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise Error {
  ignore(credentials)
  ignore(mode)
  let (req_body, req_headers) = prepare_fetch_payload(body, data, headers)
  let (origin, path) = split_fetch_url(url)
  let client = @http.Client(origin)
  defer client.close()
  try {
    client.request(
      http_method_to_async(http_method),
      path,
      extra_headers=req_headers,
    )
    match req_body {
      Some(body) => client.write(body)
      None => ()
    }
    let response = client.end_request()
    let body = client.read_all().binary()
    HttpResponse::new(
      StatusCode::from_int(response.code),
      headers=async_headers_to_views(response.headers),
      raw_body=body,
    )
  } catch {
    err => raise FetchError::RequestFailed(err.to_string())
  }
}
