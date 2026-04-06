/// A test HTTP client that calls mocket handlers directly without network I/O.
///
/// Construct routes on a `Mocket` app, then use `TestClient` to test them:
/// ```
/// let app = new()
/// app.get("/hello", fn(_) noraise { "Hello!" })
/// let client = TestClient::new(app)
/// let res = client.get("/hello")
/// assert_eq(res.status, OK)
/// ```

///|
pub struct TestClient {
  app : Mocket
}

/// The response from a `TestClient` request, containing status, headers, and body.

///|
pub struct TestResponse {
  status : StatusCode
  headers : Map[String, String]
  body_bytes : Bytes
}

/// Creates a new test client wrapping the given app.

///|
pub fn TestClient::new(app : Mocket) -> TestClient {
  { app, }
}

/// Returns the response body decoded as a UTF-8 string.

///|
pub fn TestResponse::body_text(self : TestResponse) -> String {
  @utf8.decode(self.body_bytes) catch {
    _ => ""
  }
}

/// Parses the response body as JSON into a typed value.

///|
pub fn[T : @json.FromJson] TestResponse::body_json(
  self : TestResponse,
) -> T raise {
  let text = @utf8.decode(self.body_bytes)
  let json = @json.parse(text)
  @json.from_json(json)
}

/// Sends a synthetic GET request to the given path.

///|
pub async fn TestClient::get(
  self : TestClient,
  path : String,
  headers? : Map[String, String],
) -> TestResponse {
  self.request("GET", path, headers=headers.unwrap_or({}), body=b"")
}

/// Sends a synthetic POST request with optional body.

///|
pub async fn TestClient::post(
  self : TestClient,
  path : String,
  body? : Bytes,
  headers? : Map[String, String],
) -> TestResponse {
  self.request(
    "POST",
    path,
    headers=headers.unwrap_or({}),
    body=body.unwrap_or(b""),
  )
}

/// Sends a synthetic PUT request with optional body.

///|
pub async fn TestClient::put(
  self : TestClient,
  path : String,
  body? : Bytes,
  headers? : Map[String, String],
) -> TestResponse {
  self.request(
    "PUT",
    path,
    headers=headers.unwrap_or({}),
    body=body.unwrap_or(b""),
  )
}

/// Sends a synthetic DELETE request.

///|
pub async fn TestClient::delete(
  self : TestClient,
  path : String,
  headers? : Map[String, String],
) -> TestResponse {
  self.request("DELETE", path, headers=headers.unwrap_or({}), body=b"")
}

/// Core request method — constructs a synthetic event, runs the middleware
/// chain and handler, and returns the response.

///|
pub async fn TestClient::request(
  self : TestClient,
  meth : String,
  path : String,
  headers~ : Map[String, String],
  body~ : Bytes,
) -> TestResponse {
  let request_path = @mhttp.request_target_path(path)
  // Look up route
  let (params, handler) = match self.app.lookup_http_route(meth, request_path) {
    Found(matched_handler, matched_params) => (matched_params, matched_handler)
    MethodNotAllowed(allow) => ({}, method_not_allowed_handler(allow))
    Options(allow) => ({}, options_handler(allow))
    NotFound =>
      match self.app.not_found_handler {
        Some(handler) => ({}, handler)
        None => ({}, handle_not_found())
      }
  }
  // Construct event
  let event = {
    req: { http_method: meth, url: path, headers, raw_body: body },
    res: HttpResponse::new(OK),
    params,
  }
  // Execute middleware chain + handler
  let responder = execute_middlewares(self.app.middlewares, event, handler)
  // Apply responder to response
  responder.options(event.res)
  let buf = @buffer.new()
  responder.output(buf)
  event.res.raw_body = buf.to_bytes()
  // Return test response
  {
    status: event.res.status_code,
    headers: event.res.headers,
    body_bytes: event.res.raw_body,
  }
}
