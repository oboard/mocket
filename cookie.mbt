///|
/// Adds an async HTTP runtime cookie as a `Set-Cookie` entry.
pub fn HttpResponse::set_cookie(
  self : HttpResponse,
  cookie : @http.Cookie,
) -> Unit {
  self.cookies.push(cookie)
}

///|
/// Looks up a cookie from a request's `Cookie` header.
pub fn HttpRequest::get_cookie(
  self : HttpRequest,
  name : String,
) -> @http.Cookie? {
  if self.headers.get("Cookie") is Some(cookie) {
    parse_request_cookie(cookie).get(name)
  } else {
    None
  }
}

///|
/// Parses the `Cookie` request header. Request cookies are name/value pairs;
/// `Set-Cookie` attributes never apply to this header.
pub fn parse_request_cookie(cookie : StringView) -> Map[String, @http.Cookie] {
  let result : Map[String, @http.Cookie] = Map([])
  for part in cookie.split(";") {
    if part.trim().split_once("=") is Some((name, value)) {
      let name = name.trim().to_owned()
      if name != "" {
        let value = value.trim()
        let value = if value is ['\"', .. inner, '\"'] { inner } else { value }
        result[name] = @http.Cookie(name, value.to_owned())
      }
    }
  }
  result
}

///|
pub fn HttpResponse::delete_cookie(self : HttpResponse, key : String) -> Unit {
  self.set_cookie(@http.Cookie(key, "", max_age=0L))
}

///|
/// Serializes an async HTTP cookie for non-native backends that need to write
/// `Set-Cookie` themselves.
pub fn serialize_cookie(cookie : @http.Cookie) -> String {
  let result = StringBuilder()
  result.write_string(cookie.name)
  result.write_char('=')
  result.write_string(cookie.value)
  if cookie.path is Some(path) {
    result.write_string("; Path=")
    result.write_string(path)
  }
  if cookie.expires_raw is Some(expires_raw) {
    result.write_string("; Expires=")
    result.write_string(expires_raw)
  }
  if cookie.max_age is Some(max_age) {
    result.write_string("; Max-Age=")
    result.write_string(max_age.to_string())
  }
  if cookie.domain is Some(domain) {
    result.write_string("; Domain=")
    result.write_string(domain)
  }
  if cookie.secure {
    result.write_string("; Secure")
  }
  if cookie.http_only {
    result.write_string("; HttpOnly")
  }
  for extension in cookie.extensions {
    result.write_string("; ")
    result.write_string(extension)
  }
  result.to_string()
}
