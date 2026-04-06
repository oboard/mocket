///|
/// Returns the value of a request header by name (case-insensitive), or None if not found.
pub fn HttpRequest::get_header(self : HttpRequest, name : String) -> String? {
  @mhttp.get_header_case_insensitive(self.headers, name)
}
