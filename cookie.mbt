///|
/// Sets a cookie on the response with the given name, value, and optional attributes.
pub fn HttpResponse::set_cookie(
  self : HttpResponse,
  name : String,
  value : String,
  max_age? : Int,
  path? : String,
  domain? : String,
  secure? : Bool,
  http_only? : Bool,
  same_site? : SameSiteOption,
) -> Unit {
  let item = CookieItem(
    name~,
    value~,
    max_age?,
    path?,
    domain?,
    secure?,
    http_only?,
    same_site?,
  )
  self.cookies.set(name, item)
}

///|
/// Retrieves a cookie by name from the request's Cookie header, if present.
pub fn HttpRequest::get_cookie(
  self : HttpRequest,
  name : String,
) -> CookieItem? {
  match self.get_header("cookie") {
    Some(cookie) => parse_cookie(cookie).get(name)
    None => None
  }
}

///|
/// Deletes a cookie by setting its value to empty and max-age to 0.
pub fn HttpResponse::delete_cookie(self : HttpResponse, key : String) -> Unit {
  self.set_cookie(key, "", max_age=0)
}

///|
/// Serializes an array of cookie items into a semicolon-separated string.
pub fn cookie_to_string(cookie : Array[CookieItem]) -> String {
  cookie.map(x => x.to_string()).join(";")
}

///|
/// Parses a raw cookie header string into a map of cookie names to `CookieItem` values.
pub fn parse_cookie(cookie : StringView) -> Map[String, CookieItem] {
  fn dequote(value : StringView) -> StringView {
    if value is ['"', .. rest, '"'] {
      rest
    } else {
      value
    }
  }

  let res = Map::new()
  let mut last_cookie_item : (String, CookieItem)? = None
  fn on_key_value(key : StringView, value : StringView) -> Unit {
    let key = key.to_string()
    let value = dequote(value).to_string()
    if last_cookie_item is Some((name, item)) {
      let new_item = lexmatch key with longest {
        "(?i:path)" => { ..item, path: Some(value) }
        "(?i:domain)" => { ..item, domain: Some(value) }
        "(?i:max-age)" =>
          {
            ..item,
            max_age: try @string.parse_int(value) catch {
              _ => None
            } noraise {
              x => Some(x)
            },
          }
        "(?i:secure)" => { ..item, secure: Some(true) }
        "(?i:httponly)" => { ..item, http_only: Some(true) }
        "(?i:samesite)" => {
          let same_site = lexmatch value with longest {
            "(?i:lax)" => Some(Lax)
            "(?i:strict)" => Some(Strict)
            "(?i:none)" => Some(SameSiteNone)
            _ => None
          }
          { ..item, same_site, }
        }
        _ => item
      }
      if !physical_equal(new_item, item) {
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      }
    }
    let item = CookieItem(name=key, value~)
    res.set(key, item)
    last_cookie_item = Some((key, item))
  }

  for curr = cookie {
    // TODO: more spec compliance
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#attributes
    lexmatch curr with longest {
      ("[ \t]+", rest) => continue rest
      (
        ("[^ \t=;]([ \t]*[^ \t=;])*" as key)
        "[ \t]*"
        "="
        "[ \t]*"
        ("[^ \t;]([ \t]*[^ \t;])*" as value)
        "[ \t]*"
        ";?",
        rest
      ) => {
        on_key_value(key, value)
        continue rest
      }
      (("[^ \t=;]([ \t]*[^ \t=;])*" as key) "[ \t]*" "(=[ \t]*)?" ";?", rest) => {
        on_key_value(key, "")
        continue rest
      }
      "" => break
      _ => break
    }
  }
  res
}
