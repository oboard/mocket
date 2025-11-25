///|
pub(all) struct HttpRequest {
  http_method : String
  url : String
  headers : Map[StringView, StringView]
  mut raw_body : Bytes
}

///|
pub(open) trait BodyReader {
  from_request(req: HttpRequest) -> Self raise
}

///|
pub fn[T : BodyReader] HttpRequest::body(self : HttpRequest) -> T raise {
  T::from_request(self)
}

///|
pub impl BodyReader for String with from_request(req : HttpRequest) -> String raise {
  @encoding/utf8.decode(req.raw_body)
}

///|
pub impl BodyReader for Json with from_request(req : HttpRequest) -> Json raise {
  @json.parse(@encoding/utf8.decode(req.raw_body))
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
  @json.inspect(json, content={ "Hello": "World!" })
}
