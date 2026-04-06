/// An incoming HTTP request containing the method, URL, headers, and body.

///|
pub(all) struct HttpRequest {
  http_method : HttpMethod
  url : String
  headers : Map[String, String]
  mut raw_body : Bytes
  // Lazily cached parsed path and query params to avoid re-parsing per request
  priv mut cached_path : String?
  priv mut cached_query_params : Map[String, String]?

  /// Constructor — creates a new HttpRequest.
  fn new(
    http_method : HttpMethod,
    url : String,
    headers : Map[String, String],
    raw_body? : Bytes,
  ) -> HttpRequest
}

///|
pub fn HttpRequest::new(
  http_method : HttpMethod,
  url : String,
  headers : Map[String, String],
  raw_body? : Bytes,
) -> HttpRequest {
  {
    http_method,
    url,
    headers,
    raw_body: raw_body.unwrap_or(b""),
    cached_path: None,
    cached_query_params: None,
  }
}

/// Creates a new HttpRequest from a method string.
/// Convenience constructor that parses the method string into an HttpMethod.

///|
pub fn HttpRequest::from_method_string(
  http_method : String,
  url : String,
  headers : Map[String, String],
  raw_body : Bytes,
) -> HttpRequest {
  HttpRequest::new(
    HttpMethod::from_string(http_method),
    url,
    headers,
    raw_body~,
  )
}

/// Returns the HTTP method as a string (e.g., "GET", "POST").

///|
pub fn HttpRequest::method_string(self : HttpRequest) -> String {
  self.http_method.to_method_string()
}

/// Trait for types that can be deserialized from an HTTP request body.
///
/// Implement `from_request` to define how the raw request bytes are converted
/// into the target type. Used by `event.req.body[T]()`.
///
/// Built-in implementations:
/// - `String` → UTF-8 decoded text (handles UTF-16 payloads gracefully)
/// - `Json` → parsed JSON value
/// - `Bytes` → raw bytes (zero-copy)
/// - `FixedArray[Byte]` / `Array[Byte]` → byte arrays
///
/// For typed JSON parsing, prefer `event.req.json[T]()` or `event.json[T]()`
/// which use `derive(FromJson)` directly — no `BodyReader` implementation needed.
///
/// To make your own type a body reader:
/// ```
/// struct CsvData { rows : Array[Array[String]] }
/// pub impl BodyReader for CsvData with from_request(req) {
///   let text = @utf8.decode(req.raw_body)
///   // parse CSV ...
/// }
/// ```

///|
pub(open) trait BodyReader {
  from_request(req : HttpRequest) -> Self raise
}

/// Returns the path component of the request URL, excluding query string and fragment.
///
/// The result is cached on first access — subsequent calls return the cached value
/// without re-parsing, which is important since the path is accessed by routing,
/// middleware scope matching, and user handler code.

///|
pub fn HttpRequest::path(self : HttpRequest) -> String {
  match self.cached_path {
    Some(p) => p
    None => {
      let p = @mhttp.request_target_path(self.url)
      self.cached_path = Some(p)
      p
    }
  }
}

/// Returns the raw query string from the request URL, or `None` if absent.

///|
pub fn HttpRequest::query_string(self : HttpRequest) -> String? {
  @mhttp.request_target_query_string(self.url)
}

/// Returns the Content-Type header value, or None if not set.

///|
pub fn HttpRequest::content_type(self : HttpRequest) -> String? {
  self.get_header("content-type")
}

/// Parses the query string into a map of key-value pairs.
///
/// Returns an empty map when no query string is present.
/// The result is cached on first access — subsequent calls return the cached map
/// without re-parsing.

///|
pub fn HttpRequest::query_params(self : HttpRequest) -> Map[String, String] {
  match self.cached_query_params {
    Some(params) => params
    None => {
      let params : Map[String, String] = match self.query_string() {
        Some(query) => @mhttp.parse_form_data(@utf8.encode(query)[:])
        None => {}
      }
      self.cached_query_params = Some(params)
      params
    }
  }
}

/// Looks up a single query parameter by key, returning `None` if not found.
///
/// Uses the cached query params map, so calling this multiple times with
/// different keys only parses the query string once.

///|
pub fn HttpRequest::get_query(self : HttpRequest, key : String) -> String? {
  self.query_params().get(key)
}

/// Deserializes the request body into a value of type `T` via the `BodyReader` trait.

///|
pub fn[T : BodyReader] HttpRequest::body(self : HttpRequest) -> T raise {
  T::from_request(self)
}

/// Parses the request body as JSON and deserializes into type `T`.
///
/// Works with any type that has `derive(FromJson)`. This is the recommended
/// way for AI agents and developers to extract typed data from request bodies.
///
/// Example:
/// ```
/// struct CreateUser { name : String, age : Int } derive(FromJson)
/// let user : CreateUser = event.req.json()
/// ```

///|
pub fn[T : @json.FromJson] HttpRequest::json(self : HttpRequest) -> T raise {
  let text = @utf8.decode(self.raw_body)
  let json = @json.parse(text)
  @json.from_json(json)
}

/// Tries to parse the request body as JSON, returning `Ok(T)` on success
/// or `Err(message)` on failure.
///
/// Use this when you want custom error handling instead of the automatic
/// error mapping provided by `json()`.
///
/// ```
/// match event.req.try_json() {
///   Ok(user) => HttpResponse::ok().json_value(user)
///   Err(msg) => HttpResponse::error(BadRequest, "Invalid input: \{msg}")
/// }
/// ```

///|
pub fn[T : @json.FromJson] HttpRequest::try_json(
  self : HttpRequest,
) -> Result[T, String] {
  try {
    let text = @utf8.decode(self.raw_body)
    let json = @json.parse(text)
    Ok(@json.from_json(json))
  } catch {
    err => Err(err.to_string())
  }
}

///|
test "path is cached after first access" {
  let req = HttpRequest::new(Get, "/api/users?q=test", {}, raw_body=b"")
  assert_eq(req.cached_path, None)
  let path1 = req.path()
  assert_eq(path1, "/api/users")
  assert_eq(req.cached_path, Some("/api/users"))
  // Second call returns cached value
  let path2 = req.path()
  assert_eq(path1, path2)
}

///|
test "query_params is cached after first access" {
  let req = HttpRequest::new(Get, "/search?q=hello&lang=en", {}, raw_body=b"")
  assert_eq(req.cached_query_params, None)
  let params1 = req.query_params()
  assert_eq(params1.get("q"), Some("hello"))
  assert_true(req.cached_query_params is Some(_))
  // get_query uses the cached params
  assert_eq(req.get_query("lang"), Some("en"))
  assert_eq(req.get_query("missing"), None)
}

///|
test "get_header is case-insensitive" {
  let req = HttpRequest::new(
    Get,
    "/",
    { "X-Test": "value", "content-type": "text/plain" },
    raw_body=b"",
  )
  assert_eq(req.get_header("x-test"), Some("value"))
  assert_eq(req.get_header("X-TEST"), Some("value"))
  assert_eq(req.get_header("Content-Type"), Some("text/plain"))
  assert_eq(req.get_header("missing"), None)
}

///|
test "request target helpers expose path and query" {
  let req = HttpRequest::new(
    Get,
    "/search/moonbit?q=async%20native&lang=en#frag",
    {},
    raw_body=b"",
  )
  assert_eq(req.path(), "/search/moonbit")
  assert_eq(req.query_string(), Some("q=async%20native&lang=en"))
  assert_eq(req.get_query("q"), Some("async native"))
  assert_eq(req.get_query("lang"), Some("en"))
  assert_eq(req.get_query("missing"), None)
}

///|
pub impl BodyReader for String with from_request(req : HttpRequest) -> String raise {
  let bytes = req.raw_body
  let arr = bytes.to_array()
  if arr.length() > 0 {
    let mut zero_count = 0
    arr.each(fn(b) { if b == b'\x00' { zero_count = zero_count + 1 } })
    // Some servers may return UTF-16-ish payloads for HTML; printing such
    // strings directly often looks like only a few characters (e.g. "<h").
    if zero_count * 4 > arr.length() {
      let filtered = arr.filter(fn(b) { b != b'\x00' })
      return @utf8.decode(Bytes::from_array(filtered))
    }
  }
  @utf8.decode(bytes)
}

///|
pub impl BodyReader for Json with from_request(req : HttpRequest) -> Json raise {
  @json.parse(@utf8.decode(req.raw_body))
}

///|
pub impl BodyReader for Bytes with from_request(req : HttpRequest) -> Bytes raise {
  req.raw_body
}

///|
pub impl BodyReader for FixedArray[Byte] with from_request(req : HttpRequest) -> FixedArray[
  Byte,
] raise {
  req.raw_body.to_fixedarray()
}

///|
pub impl BodyReader for Array[Byte] with from_request(req : HttpRequest) -> Array[
  Byte,
] raise {
  req.raw_body.to_array()
}

///|
test "read_body" {
  let req = HttpRequest::new(
    Post,
    "/",
    Map::new(),
    raw_body=b"{\"Hello\":\"World!\"}",
  )
  let text : String = req.body()
  let json : Json = req.body()
  inspect(
    text,
    content=(
      #|{"Hello":"World!"}
    ),
  )
  json_inspect(json, content={ "Hello": "World!" })
}

///|
struct TryJsonTestUser {
  name : String
  age : Int
} derive(FromJson, ToJson, Eq)

///|
impl Show for TryJsonTestUser with output(self, logger) {
  logger.write_string(
    "TryJsonTestUser { name: \{self.name}, age: \{self.age} }",
  )
}

///|
test "try_json returns Ok on valid json" {
  let req = HttpRequest::new(
    Post,
    "/",
    {},
    raw_body=@utf8.encode("{\"name\":\"Alice\",\"age\":30}"),
  )
  let result : Result[TryJsonTestUser, String] = req.try_json()
  assert_eq(result, Ok({ name: "Alice", age: 30 }))
}

///|
test "try_json returns Err on invalid json" {
  let req = HttpRequest::new(Post, "/", {}, raw_body=b"not valid json")
  let result : Result[TryJsonTestUser, String] = req.try_json()
  assert_true(result is Err(_))
}

///|
test "try_json returns Err on wrong schema" {
  let req = HttpRequest::new(
    Post,
    "/",
    {},
    raw_body=@utf8.encode("{\"wrong_field\":123}"),
  )
  let result : Result[TryJsonTestUser, String] = req.try_json()
  assert_true(result is Err(_))
}
