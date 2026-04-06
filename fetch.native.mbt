///|
priv enum FetchProtocol {
  Http
  Https
}

///|
fn FetchProtocol::default_port(self : FetchProtocol) -> Int {
  match self {
    Http => 80
    Https => 443
  }
}

///|
fn FetchProtocol::scheme(self : FetchProtocol) -> String {
  match self {
    Http => "http"
    Https => "https"
  }
}

///|
fn request_method_to_async(http_method : HttpMethod) -> @http.RequestMethod {
  match http_method {
    Get => Get
    Post => Post
    Put => Put
    Patch => Patch
    Delete => Delete
    Head => Head
    Options => Options
    Trace => Trace
    Connect => Connect
    Other(_) => Get
  }
}

///|
fn response_headers_from_async(
  headers : Map[String, String],
) -> Map[String, String] {
  let copied : Map[String, String] = {}
  headers.each((key, value) => copied.set(key, value))
  copied
}

///|
fn resolve_fetch_url(
  url : String,
) -> (FetchProtocol, String, Int, String) raise Error {
  guard url.find("://") is Some(protocol_len) else {
    raise FetchError::RequestFailed("invalid URL: \{url}")
  }
  let protocol = match url[:protocol_len] {
    "http" => Http
    "https" => Https
    other => raise FetchError::RequestFailed("unsupported protocol: \{other}")
  }
  let remainder = url[protocol_len + 3:]
  let mut authority_end = remainder.length()
  match remainder.find("/") {
    Some(index) => if index < authority_end { authority_end = index }
    None => ()
  }
  match remainder.find("?") {
    Some(index) => if index < authority_end { authority_end = index }
    None => ()
  }
  match remainder.find("#") {
    Some(index) => if index < authority_end { authority_end = index }
    None => ()
  }
  let authority = remainder[:authority_end].to_string()
  let raw_path = if authority_end < remainder.length() {
    remainder[authority_end:].to_string()
  } else {
    "/"
  }
  guard authority != "" else {
    raise FetchError::RequestFailed("invalid URL: \{url}")
  }
  let (host, port) = if authority lexmatch? (host, ":" ("[0-9]+" as port_text)) {
    let parsed_port = @string.parse_int(port_text) catch {
      _ => raise FetchError::RequestFailed("invalid URL: \{url}")
    }
    guard parsed_port is (1..<65536) else {
      raise FetchError::RequestFailed("invalid URL: \{url}")
    }
    (host.to_string(), parsed_port)
  } else {
    (authority, protocol.default_port())
  }
  guard host != "" else {
    raise FetchError::RequestFailed("invalid URL: \{url}")
  }
  let normalized_path = match raw_path.find("#") {
    Some(index) => if index == 0 { "/" } else { raw_path[:index].to_string() }
    None =>
      if raw_path == "" {
        "/"
      } else if raw_path.has_prefix("?") {
        "/" + raw_path
      } else {
        raw_path
      }
  }
  (protocol, host, port, normalized_path)
}

///|
fn fetch_origin(protocol : FetchProtocol, host : String, port : Int) -> String {
  if port == protocol.default_port() {
    "\{protocol.scheme()}://\{host}"
  } else {
    "\{protocol.scheme()}://\{host}:\{port}"
  }
}

///|
fn prepare_fetch_payload_bytes(
  body : String?,
  data : &Responder?,
  headers : Map[String, String]?,
) -> (Bytes?, Map[String, String]) {
  let req_headers = copy_headers(headers.unwrap_or({}))
  let req_body = match body {
    Some(raw_body) => Some(@utf8.encode(raw_body))
    None =>
      match data {
        Some(responder_data) => {
          let res = HttpResponse(OK)
          responder_data.options(res)
          res.headers.each((key, value) => {
            if !@mhttp.has_header_case_insensitive(req_headers, key) {
              req_headers.set(key.to_string(), value.to_string())
            }
          })
          let body_buf = @buffer.new()
          responder_data.output(body_buf)
          Some(body_buf.to_bytes())
        }
        None => None
      }
  }
  (req_body, req_headers)
}

///|
/// Sends an HTTP request to the given URL and returns the response.
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
  let (req_body, req_headers) = prepare_fetch_payload_bytes(body, data, headers)
  let (protocol, host, port, path) = resolve_fetch_url(url)
  let client = @http.Client::new(fetch_origin(protocol, host, port)) catch {
    err => raise FetchError::RequestFailed("\{err}")
  }
  defer client.close()
  let response = try {
    client.request(
      request_method_to_async(http_method),
      path,
      extra_headers=req_headers,
    )
    match req_body {
      Some(body_bytes) => client.write(body_bytes)
      None => ()
    }
    client.end_request()
  } catch {
    err => raise FetchError::RequestFailed("\{err}")
  }
  let response_body = client.read_all().binary() catch {
      err => raise FetchError::RequestFailed("\{err}")
    }
  HttpResponse(
    StatusCode::from_int(response.code),
    headers=response_headers_from_async(response.headers),
    raw_body=response_body,
  )
}
