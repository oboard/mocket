///|
fn header_name_matches(left : String, right : String) -> Bool {
  left.to_lower() == right.to_lower()
}

///|
fn get_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> String? {
  for pair in headers {
    let (key, value) = pair
    if header_name_matches(key, header_name) {
      return Some(value)
    }
  }
  None
}

///|
fn has_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> Bool {
  get_header_case_insensitive(headers, header_name) is Some(_)
}

///|
pub fn HttpRequest::get_header(self : HttpRequest, name : String) -> String? {
  get_header_case_insensitive(self.headers, name)
}
