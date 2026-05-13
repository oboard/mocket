///|
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
  let item : CookieItem = {
    name,
    value,
    max_age,
    path,
    domain,
    secure,
    http_only,
    same_site,
  }
  self.cookies.set(name, item)
}

///|
pub fn HttpRequest::get_cookie(
  self : HttpRequest,
  name : String,
) -> CookieItem? {
  if self.headers.get("Cookie") is Some(cookie) {
    parse_cookie(cookie).get(name)
  } else if self.headers.get("cookie") is Some(cookie) {
    parse_cookie(cookie).get(name)
  } else {
    None
  }
}

///|
pub fn HttpResponse::delete_cookie(self : HttpResponse, key : String) -> Unit {
  self.set_cookie(key, "", max_age=0)
}

///|
pub fn cookie_to_string(cookie : Array[CookieItem]) -> String {
  cookie.map(x => x.to_string()).join(";")
}

///|
pub fn parse_cookie(cookie : StringView) -> Map[String, CookieItem] {
  fn dequote(value : StringView) -> StringView {
    if value is ['"', .. rest, '"'] {
      rest
    } else {
      value
    }
  }

  let res = Map([])
  let mut last_cookie_item : (String, CookieItem)? = None
  fn on_key_value(key : StringView, value : StringView) -> Unit {
    let key = key.to_owned()
    let value = dequote(value).to_owned()
    if last_cookie_item is Some((name, item)) {
      if key =~ re"^(?i:path)$" {
        let new_item = { ..item, path: Some(value) }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      } else if key =~ re"^(?i:domain)$" {
        let new_item = { ..item, domain: Some(value) }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      } else if key =~ re"^(?i:max-age)$" {
        let new_item = {
          ..item,
          max_age: try @string.parse_int(value) catch {
            _ => None
          } noraise {
            x => Some(x)
          },
        }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      } else if key =~ re"^(?i:secure)$" {
        let new_item = { ..item, secure: Some(true) }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      } else if key =~ re"^(?i:httponly)$" {
        let new_item = { ..item, http_only: Some(true) }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      } else if key =~ re"^(?i:samesite)$" {
        let same_site = if value =~ re"^(?i:lax)$" {
          Some(Lax)
        } else if value =~ re"^(?i:strict)$" {
          Some(Strict)
        } else if value =~ re"^(?i:none)$" {
          Some(SameSiteNone)
        } else {
          None
        }
        let new_item = { ..item, same_site, }
        res.set(name, new_item)
        last_cookie_item = Some((name, new_item))
        return
      }
    }
    let item = CookieItem::{
      name: key,
      value,
      max_age: None,
      path: None,
      domain: None,
      secure: None,
      http_only: None,
      same_site: None,
    }
    res.set(key, item)
    last_cookie_item = Some((key, item))
  }

  for curr = cookie {
    // TODO: more spec compliance
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#attributes
    if curr =~ (re"^[ \t]+", after=rest) {
      continue rest
    } else if curr =~ (
        re"^" +
        (re"[^ \t=;]([ \t]*[^ \t=;])*" as key) +
        re"[ \t]*=[ \t]*" +
        (re"[^ \t;]([ \t]*[^ \t;])*" as value) +
        re"[ \t]*;?",
        after=rest,
      ) {
      on_key_value(key, value)
      continue rest
    } else if curr =~ (
        re"^" +
        (re"[^ \t=;]([ \t]*[^ \t=;])*" as key) +
        re"[ \t]*(=[ \t]*)?;?",
        after=rest,
      ) {
      on_key_value(key, "")
      continue rest
    } else {
      break
    }
  }
  res
}
