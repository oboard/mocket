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
  cookie.map(_.to_string()).join(";")
}

///|

///|

///|
pub fn parse_cookie(cookie : StringView) -> Map[String, CookieItem] {
  let res = Map::new()
  let mut view = cookie
  let mut last_cookie_name = ""
  while view.length() > 0 {
    // Skip whitespace using lexmatch
    while true {
      if view lexmatch? (" ", rest) {
        view = rest
        continue
      }
      if view lexmatch? ("\t", rest) {
        view = rest
        continue
      }
      break
    }
    if view.length() == 0 {
      break
    }

    // Parse key
    let mut key_end = 0
    while key_end < view.length() &&
          view[key_end] != '=' &&
          view[key_end] != ';' {
      key_end = key_end + 1
    }
    let key = view[0:key_end].trim_space().to_string() catch { _ => "" }
    view = view[key_end:] catch { _ => view }

    // Parse value
    let mut val = ""
    if view lexmatch? ("=", rest) {
      view = rest
      // Skip whitespace
      while true {
        if view lexmatch? (" ", rest) {
          view = rest
          continue
        }
        if view lexmatch? ("\t", rest) {
          view = rest
          continue
        }
        break
      }
      if view lexmatch? ("\"", rest) {
        // Quoted value
        view = rest
        let mut q_end = 0
        while q_end < view.length() && view[q_end] != '"' {
          q_end = q_end + 1
        }
        val = view[0:q_end].to_string() catch { _ => "" }
        // Skip closing quote if present
        if q_end < view.length() {
          view = view[q_end + 1:] catch {
              _ => view[q_end:] catch { _ => view }
            }
        } else {
          view = view[q_end:] catch { _ => view }
        }
      } else {
        // Unquoted value
        let mut v_end = 0
        while v_end < view.length() && view[v_end] != ';' {
          v_end = v_end + 1
        }
        val = view[0:v_end].trim_space().to_string() catch { _ => "" }
        view = view[v_end:] catch { _ => view }
      }
    }
    if key != "" {
      let lower_key = key.to_lower()
      if last_cookie_name != "" &&
        (
          lower_key == "path" ||
          lower_key == "domain" ||
          lower_key == "max-age" ||
          lower_key == "secure" ||
          lower_key == "httponly" ||
          lower_key == "samesite"
        ) {
        // It's an attribute for the last cookie
        match res.get(last_cookie_name) {
          Some(item) => {
            let mut new_item : CookieItem = item
            match lower_key {
              "path" => new_item = { ..item, path: Some(val) }
              "domain" => new_item = { ..item, domain: Some(val) }
              "max-age" =>
                new_item = {
                  ..item,
                  max_age: Some(@strconv.parse_int(val)) catch {
                    _ => None
                  },
                }
              "secure" => new_item = { ..item, secure: Some(true) }
              "httponly" => new_item = { ..item, http_only: Some(true) }
              "samesite" => {
                let same_site = match val.to_lower() {
                  "lax" => Some(Lax)
                  "strict" => Some(Strict)
                  "none" => Some(SameSiteNone)
                  _ => None
                }
                new_item = { ..item, same_site, }
              }
              _ => ()
            }
            res.set(last_cookie_name, new_item)
          }
          None => ()
        }
      } else {
        // New cookie
        let item : CookieItem = {
          name: key,
          value: val,
          max_age: None,
          path: None,
          domain: None,
          secure: None,
          http_only: None,
          same_site: None,
        }
        res.set(key, item)
        last_cookie_name = key
      }
    }

    // Skip until next semicolon
    if view lexmatch? (";", rest) {
      view = rest
    } else {
      // Skip invalid chars until ;
      let mut i = 0
      while i < view.length() && view[i] != ';' {
        i = i + 1
      }
      if i < view.length() {
        view = view[i + 1:] catch { _ => view }
      } else {
        view = view[i:] catch { _ => view }
      }
    }
  }
  res
}
