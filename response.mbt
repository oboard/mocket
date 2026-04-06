/// An outgoing HTTP response containing the status code, headers, cookies, and body.

///|
pub(all) struct HttpResponse {
  mut status_code : StatusCode
  headers : Map[String, String]
  cookies : Map[String, CookieItem]
  mut raw_body : Bytes

  fn new(
    status_code : StatusCode,
    headers? : Map[String, String],
    cookies? : Map[String, CookieItem],
    raw_body? : Bytes,
  ) -> HttpResponse
}

/// Deserializes the response body into a value of type `T` via the `BodyReader` trait.

///|
pub fn[T : BodyReader] HttpResponse::read_body(self : HttpResponse) -> T raise {
  T::from_request(
    HttpRequest::new(Other(""), "", self.headers, raw_body=self.raw_body),
  )
}

/// Creates a new `HttpResponse` with the given status code and optional headers, cookies, and body.

///|
pub fn HttpResponse::new(
  status_code : StatusCode,
  headers? : Map[String, String],
  cookies? : Map[String, CookieItem],
  raw_body? : Bytes,
) -> HttpResponse {
  HttpResponse::{
    status_code,
    headers: headers.unwrap_or({}),
    cookies: cookies.unwrap_or({}),
    raw_body: raw_body.unwrap_or(""),
  }
}

/// Sets the response body from any `Responder` and returns the response for chaining.

///|
pub fn HttpResponse::body(
  self : HttpResponse,
  body : &Responder,
) -> HttpResponse {
  let buf = @buffer.new()
  body.output(buf)
  self.raw_body = buf.to_bytes()
  self
}

/// Sets the response body to the JSON representation of the given value.

///|
pub fn HttpResponse::json(self : HttpResponse, obj : &ToJson) -> HttpResponse {
  self.body(obj.to_json())
}

/// Serializes a typed value as JSON, sets Content-Type, and returns the response.
///
/// This is the recommended way to return typed data from handlers.
/// Works with any type that has `derive(ToJson)`.
///
/// Example:
/// ```
/// struct User { name : String } derive(ToJson)
/// HttpResponse::ok().json_value({ name: "Alice" })
/// ```

///|
pub fn[T : ToJson] HttpResponse::json_value(
  self : HttpResponse,
  value : T,
) -> HttpResponse {
  self.headers.set("Content-Type", "application/json; charset=utf-8")
  let json_str = value.to_json().stringify()
  self.raw_body = @utf8.encode(json_str)
  self
}

/// Sets a response header and returns self for fluent chaining.
///
/// ```mbt check
/// test {
///   let res = @crescent.HttpResponse::ok().header("X-Custom", "value")
///   inspect(res.headers.get("X-Custom"), content="Some(\"value\")")
/// }
/// ```

///|
pub fn HttpResponse::header(
  self : HttpResponse,
  name : String,
  value : String,
) -> HttpResponse {
  self.headers.set(name, value)
  self
}

/// Converts this response into a `Responder` trait object for use as a handler return value.

///|
pub fn HttpResponse::to_responder(self : HttpResponse) -> &Responder {
  self
}

///|
test "read_response_body" {
  let res = HttpResponse::new(OK, raw_body=b"{\"Hello\":\"Response\"}")
  let text : String = res.read_body()
  let json : Json = res.read_body()
  inspect(
    text,
    content=(
      #|{"Hello":"Response"}
    ),
  )
  json_inspect(json, content={ "Hello": "Response" })
}
