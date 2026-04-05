///|
pub fn url_decode(bytes : BytesView) -> String {
  @mhttp.url_decode(bytes)
}

///|
pub fn url_encode(s : String) -> String {
  @mhttp.url_encode(s)
}

///|
pub fn parse_form_data(bytes : BytesView) -> Map[String, String] {
  @mhttp.parse_form_data(bytes)
}

///|
pub fn form_encode(map : Map[String, String]) -> String {
  @mhttp.form_encode(map)
}

///|
pub fn parse_multipart(
  bytes : BytesView,
  boundary : String,
) -> Map[String, @mhttp.MultipartFormValue] {
  @mhttp.parse_multipart(bytes, boundary)
}
