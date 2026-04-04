///|
pub(all) struct HttpRequest {
  http_method : String
  url : String
  headers : Map[String, String]
  mut raw_body : Bytes
}

///|
pub(open) trait BodyReader {
  from_request(req : HttpRequest) -> Self raise
}

///|
pub fn HttpRequest::path(self : HttpRequest) -> String {
  request_target_path(self.url)
}

///|
pub fn HttpRequest::query_string(self : HttpRequest) -> String? {
  request_target_query_string(self.url)
}

///|
pub fn HttpRequest::query_params(self : HttpRequest) -> Map[String, String] {
  match self.query_string() {
    Some(query) => parse_form_data(@utf8.encode(query)[:])
    None => {}
  }
}

///|
pub fn HttpRequest::get_query(self : HttpRequest, key : String) -> String? {
  self.query_params().get(key)
}

///|
pub fn[T : BodyReader] HttpRequest::body(self : HttpRequest) -> T raise {
  T::from_request(self)
}

///|
test "get_header is case-insensitive" {
  let req = HttpRequest::{
    http_method: "GET",
    url: "/",
    headers: { "X-Test": "value", "content-type": "text/plain" },
    raw_body: b"",
  }
  assert_eq(req.get_header("x-test"), Some("value"))
  assert_eq(req.get_header("X-TEST"), Some("value"))
  assert_eq(req.get_header("Content-Type"), Some("text/plain"))
  assert_eq(req.get_header("missing"), None)
}

///|
test "request target helpers expose path and query" {
  let req = HttpRequest::{
    http_method: "GET",
    url: "/search/moonbit?q=async%20native&lang=en#frag",
    headers: {},
    raw_body: b"",
  }
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
  let req = HttpRequest::{
    http_method: "POST",
    url: "/",
    headers: Map::new(),
    raw_body: b"{\"Hello\":\"World!\"}",
  }
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
