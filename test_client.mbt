/// A test HTTP client that calls mocket handlers directly without network I/O.
///
/// Construct routes on a `Mocket` app, then use `TestClient` to test them:
/// ```
/// let app = Mocket::new()
/// app.get("/hello", _ => "Hello!")
/// let client = TestClient::new(app)
/// let res = client.get("/hello")
/// assert_eq(res.status, OK)
/// ```

///|
pub struct TestClient {
  priv app : Mocket

  fn new(app : Mocket) -> TestClient
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

/// Core request method — dispatches a synthetic request through the full
/// routing + middleware pipeline via the public `dispatch` API.

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
