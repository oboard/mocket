///|
fn header_name_matches(left : String, right : String) -> Bool {
  left.to_lower() == right.to_lower()
}

///|
fn find_header_key_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> String? {
  for pair in headers {
    let (key, _) = pair
    if header_name_matches(key, header_name) {
      return Some(key)
    }
  }
  None
}

///|
fn get_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> String? {
  match find_header_key_case_insensitive(headers, header_name) {
    Some(key) => headers.get(key)
    None => None
  }
}

///|
fn has_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
) -> Bool {
  get_header_case_insensitive(headers, header_name) is Some(_)
}

///|
fn set_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
  value : String,
) -> Unit {
  match find_header_key_case_insensitive(headers, header_name) {
    Some(existing_key) if existing_key != header_name => {
      ignore(headers.remove(existing_key))
      headers.set(header_name, value)
    }
    Some(existing_key) => headers.set(existing_key, value)
    None => headers.set(header_name, value)
  }
}

///|
fn set_missing_header_case_insensitive(
  headers : Map[String, String],
  header_name : String,
  value : String,
) -> Unit {
  if !has_header_case_insensitive(headers, header_name) {
    headers.set(header_name, value)
  }
}

///|
fn merge_headers_case_insensitive(
  target : Map[String, String],
  source : Map[String, String],
) -> Unit {
  source.each((key, value) => set_header_case_insensitive(target, key, value))
}

///|
pub fn HttpRequest::get_header(self : HttpRequest, name : String) -> String? {
  get_header_case_insensitive(self.headers, name)
}
