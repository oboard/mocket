///|
pub fn HttpRequest::get_header(self : HttpRequest, name : String) -> String? {
  @mhttp.get_header_case_insensitive(self.headers, name)
}
