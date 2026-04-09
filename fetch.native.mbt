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
fn request_method_to_async(
  http_method : HttpMethod,
) -> @http.RequestMethod raise Error {
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
    Other(m) => raise FetchError::RequestFailed("unsupported HTTP method: \{m}")
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

/// Converts a BytesView (from the uri package) to a String by UTF-8 decoding.

///|
fn bytesview_to_string(bv : BytesView) -> String raise Error {
  @utf8.decode(Bytes::from_iter(bv.iter())) catch {
    _ => raise FetchError::RequestFailed("non-UTF-8 URL component")
  }
}

///|
fn resolve_fetch_url(
  url : String,
) -> (FetchProtocol, String, Int, String) raise Error {
  // Parse the URL using the proper RFC 3986 parser from the uri package.
  let parsed = @uri.Uri::parse(@utf8.encode(url)[:]) catch {
    _ => raise FetchError::RequestFailed("invalid URL: \{url}")
  }

  // Extract and validate scheme (must be http or https).
  let scheme_bv = match parsed.scheme {
    Some(s) => s
    None => raise FetchError::RequestFailed("invalid URL: \{url} (no scheme)")
  }
  let scheme = bytesview_to_string(scheme_bv).to_lower()
  let protocol = match scheme {
    "http" => Http
    "https" => Https
    other => raise FetchError::RequestFailed("unsupported protocol: \{other}")
  }

  // Extract authority (host + port).
  let authority = match parsed.authority {
    Some(a) => a
    None => raise FetchError::RequestFailed("invalid URL: \{url} (no host)")
  }

  // Reject URLs with userinfo — we don't silently drop credentials.
  // Users should pass credentials via the `headers` param (e.g. Authorization).
  match authority.userinfo {
    Some(_) =>
      raise FetchError::RequestFailed(
        "URL userinfo (user:pass@) is not supported; use the Authorization header instead",
      )
    None => ()
  }

  // Extract host: IPv6 literals need to be wrapped in brackets for the
  // HTTP Host header and URL reconstruction.
  let host = match authority.host {
    IPv6Address(addr) => "[" + bytesview_to_string(addr) + "]"
    RegName(name) => bytesview_to_string(name)
  }
  guard host != "" && host != "[]" else {
    raise FetchError::RequestFailed("invalid URL: \{url} (empty host)")
  }

  // Extract port, defaulting to protocol default if not specified.
  let port = match authority.port {
    Some(p) => {
      guard p is (1..<65536) else {
        raise FetchError::RequestFailed("invalid URL: \{url} (bad port)")
      }
      p
    }
    None => protocol.default_port()
  }

  // Reconstruct the request path from segments and query.
  // The path segments array always has a leading empty segment for "/".
  let path_buf = StringBuilder::new()
  for seg in parsed.path {
    path_buf.write_string("/")
    path_buf.write_string(bytesview_to_string(seg))
  }
  let mut path_str = path_buf.to_string()
  if path_str == "" {
    path_str = "/"
  }
  match parsed.query {
    Some(q) => path_str = path_str + "?" + bytesview_to_string(q)
    None => ()
  }
  (protocol, host, port, path_str)
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
