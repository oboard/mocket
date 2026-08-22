///|
pub(all) struct HttpRequest {
  http_method : String
  /// The request-target path, without query string or fragment.
  /// Routing matches against this value.
  url : String
  /// The raw query string without the leading `?`; empty when absent.
  /// Fragments (`#...`) are stripped.
  query : String
  /// Case-insensitive request headers (HTTP field names are case-insensitive).
  headers : Map[@http.CaseInsensitiveString, StringView]
  mut raw_body : Bytes
}

///|
pub(open) trait BodyReader {
  fn from_request(req : HttpRequest) -> Self raise
}

///|
pub fn[T : BodyReader] HttpRequest::body(self : HttpRequest) -> T raise {
  T::from_request(self)
}

///|
pub fn[T : FromJson] HttpRequest::json(self : HttpRequest) -> T raise {
  @json.from_json(self.body())
}

///|
// 返回 URL 解码后的查询参数键值对。例如 `GET /search?q=moon&page=2`
// 得到 `{ "q": "moon", "page": "2" }`。
pub fn HttpRequest::query(self : HttpRequest) -> Map[String, String] {
  parse_query(self.query)
}

///|
pub impl BodyReader for String with fn from_request(req : HttpRequest) -> String raise {
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
pub impl BodyReader for Json with fn from_request(req : HttpRequest) -> Json raise {
  @json.parse(@utf8.decode(req.raw_body))
}

///|
pub impl BodyReader for Bytes with fn from_request(req : HttpRequest) -> Bytes raise {
  req.raw_body
}

///|
pub impl BodyReader for FixedArray[Byte] with fn from_request(req : HttpRequest) -> FixedArray[
  Byte,
] raise {
  req.raw_body.to_fixedarray()
}

///|
pub impl BodyReader for Array[Byte] with fn from_request(req : HttpRequest) -> Array[
  Byte,
] raise {
  req.raw_body.to_array()
}

///|
test "read_body" {
  let req = HttpRequest::{
    http_method: "POST",
    url: "/",
    query: "",
    headers: Map([]),
    raw_body: b"{\"Hello\":\"World!\"}",
  }
  let text : String = req.body()
  let json : Json = req.body()
  debug_inspect(
    text,
    content=(
      #|"{\"Hello\":\"World!\"}"
    ),
  )
  json_inspect(json, content={ "Hello": "World!" })
}

///|
test "query_parsing" {
  let req = HttpRequest::{
    http_method: "GET",
    url: "/search",
    query: "q=moon&page=2&tag=hello+world",
    headers: Map([]),
    raw_body: b"",
  }
  let map = req.query()
  @test.assert_eq(map.get("q").unwrap_or(""), "moon")
  @test.assert_eq(map.get("page").unwrap_or(""), "2")
  @test.assert_eq(map.get("tag").unwrap_or(""), "hello world")
  let empty = HttpRequest::{
    http_method: "GET",
    url: "/plain",
    query: "",
    headers: Map([]),
    raw_body: b"",
  }
  @test.assert_eq(empty.query().length(), 0)
}
