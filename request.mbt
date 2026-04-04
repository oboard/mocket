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
pub fn[T : BodyReader] HttpRequest::body(self : HttpRequest) -> T raise {
  T::from_request(self)
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
