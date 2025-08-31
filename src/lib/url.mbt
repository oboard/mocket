///|
pub struct URL {
  protocol : String?
  host : String?
  port : Int?
  path : String
  query : Map[String, String]?
  fragment : String?
} derive(Show)

///|
pub fn URL::parse(rawUrl : String) -> URL {
  let url = rawUrl.trim_space()
  let scheme_end = url.find("://").unwrap_or(0)
  let fragment_start = url.find("#").unwrap_or(-1)
  let query_start = url.find("?").unwrap_or(-1)
  let query_end = if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  let port_start = if scheme_end + 3 < url.length() {
    url.view(start_offset=scheme_end + 3).find(":").unwrap_or(-1)
  } else {
    -1
  }
  let port_end = if port_start != -1 {
    url.view(start_offset=port_start).find("/").unwrap_or(-1)
  } else {
    0
  }
  let protocol = if scheme_end != -1 {
    Some(url.view(start_offset=0, end_offset=scheme_end).to_string())
  } else {
    None
  }
  let host_start = if scheme_end != -1 { scheme_end + 3 } else { 0 }
  let host_end = if port_start != -1 {
    port_start
  } else if query_start != -1 {
    query_start
  } else if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  let host = if url.contains(".") {
    Some(url.view(start_offset=host_start, end_offset=host_end).to_string())
  } else {
    None
  }
  let port_str = url.view(start_offset=port_start + 1, end_offset=port_end)
  let port = if port_str.length() > 0 {
    Some(@strconv.parse_int(port_str.to_string())) catch {
      _ => None
    }
  } else {
    None
  }
  let path_start = if port_end != -1 {
    port_end
  } else if query_start != -1 {
    query_start
  } else if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  let path_end = if query_start != -1 {
    query_start
  } else if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  // println("path_Start: \(path_start), path_End: \(path_end)")
  let path = url.view(start_offset=path_start, end_offset=path_end).to_string()
  let query = if query_start != -1 {
    let query_str = url.view(start_offset=query_start + 1, end_offset=query_end)
    Some(query_map(query_str.to_string()))
  } else {
    None
  }
  let fragment = if fragment_start != -1 {
    Some(
      url
      .view(start_offset=fragment_start + 1, end_offset=url.length())
      .to_string(),
    )
  } else {
    None
  }
  return { protocol, host, port, path, query, fragment }
}

///|
fn query_map(query_str : String) -> Map[String, String] {
  let query_array = query_str.split("&")
  query_array.map(item => {
    if item.split("=").to_array() is [key, value] {
      let key = key.to_string()
      let value = value.to_string()
      return (key, value)
    }
    return (item.to_string(), "")
  })
  |> Map::from_iter
}

///|
pub fn URL::output(self : URL, logger : Logger) -> Unit {
  logger.debug(fn() { self.to_string() })
}

///|
pub fn URL::to_string(self : URL) -> String {
  let protocol = if self.protocol is Some(p) { p + "://" } else { "" }
  let host = if self.host is Some(h) { h } else { "" }
  let port = self.port
  let path = self.path
  let query = self.query
  let fragment = self.fragment
  let port_str = if port is Some(p) { ":" + p.to_string() } else { "" }
  let query_str = if query is Some(q) {
    "?" +
    q
    .to_array()
    .map(item => {
      let (k, v) = item
      k + "=" + v
    })
    .join("&")
  } else {
    ""
  }
  let fragment_str = if fragment is Some(f) { "#" + f } else { "" }
  protocol + host + port_str + path + query_str + fragment_str
}

///|
test "parse_url" {
  let url = "/path/to/resource?name=ferret&color=purple#section1"
  let result = URL::parse(url)
  // println(url)
  // println(result)
  inspect(result.path, content="/path/to/resource")
}

///|
test "empty_url" {
  let url = ""
  let result = URL::parse(url)
  // println(url)
  // println(result)
  inspect(result.path, content="")
}
