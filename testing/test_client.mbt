/// A test HTTP client that calls handlers directly without network I/O.
///
/// Construct routes on a `Mocket` app, then use `TestClient` to test them:
///
/// ```
/// let app = @crescent.Mocket::new()
/// app.get("/hello", _ => "Hello!")
/// let client = @testing.TestClient::new(app)
/// let res = client.get("/hello")
/// assert_eq(res.status, @crescent.OK)
/// assert_eq(res.body_text(), "Hello!")
/// ```

///|
pub struct TestClient {
  priv app : @crescent.Mocket

  fn new(app : @crescent.Mocket) -> TestClient
}

/// The response from a `TestClient` request, containing status, headers, and body.

///|
pub struct TestResponse {
  /// HTTP status code of the response
  status : @crescent.StatusCode
  /// Response headers
  headers : Map[String, String]
  /// Raw response body bytes
  body_bytes : Bytes
}

/// Creates a new test client wrapping the given app.

///|
pub fn TestClient::new(app : @crescent.Mocket) -> TestClient {
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
///
/// Works with any type that has `derive(FromJson)`.

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

/// Core request method — dispatches a synthetic request through the full
/// routing + middleware pipeline and returns the response.

///|
pub async fn TestClient::request(
  self : TestClient,
  meth : String,
  path : String,
  headers~ : Map[String, String],
  body~ : Bytes,
) -> TestResponse {
  let (status, resp_headers, body_bytes) = self.app.dispatch(
    meth, path, headers, body,
  )
  { status, headers: resp_headers, body_bytes }
}
