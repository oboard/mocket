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
  let scheme_end = url.find("://").or(0)
  let fragment_start = url.find("#").or(-1)
  let query_start = url.find("?").or(-1)
  let query_end = if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  let port_start = if scheme_end + 3 < url.length() {
    url.charcodes(start=scheme_end + 3).find(":").or(-1)
  } else {
    -1
  }
  let port_end = if port_start != -1 {
    url.charcodes(start=port_start).find("/").or(-1)
  } else {
    0
  }
  let protocol = if scheme_end != -1 {
    Some(url.charcodes(start=0, end=scheme_end).to_string())
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
    Some(url.charcodes(start=host_start, end=host_end).to_string())
  } else {
    None
  }
  let port_str = url.charcodes(start=port_start + 1, end=port_end)
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
  let path = url.charcodes(start=path_start, end=path_end).to_string()
  let query = if query_start != -1 {
    let query_str = url.charcodes(start=query_start + 1, end=query_end)
    Some(query_map(query_str.to_string()))
  } else {
    None
  }
  let fragment = if fragment_start != -1 {
    Some(url.charcodes(start=fragment_start + 1, end=url.length()).to_string())
  } else {
    None
  }
  return { protocol, host, port, path, query, fragment }
}

///|
fn query_map(query_str : String) -> Map[String, String] {
  let query_array = query_str.split("&")
  query_array.map(fn(s) {
    let array = s.split("=").to_array()
    let key = array[0].to_string()
    let value = array[1].to_string()
    return (key, value)
  })
  |> Map::from_iter
}

///|
pub fn URL::output(self : URL, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn URL::to_string(self : URL) -> String {
  let protocol = match self.protocol {
    Some(p) => p + "://"
    None => ""
  }
  let host = match self.host {
    Some(h) => h
    None => ""
  }
  let port = self.port
  let path = self.path
  let query = self.query
  let fragment = self.fragment
  let port_str = match port {
    Some(p) => ":" + p.to_string()
    None => ""
  }
  let query_str = match query {
    Some(q) =>
      "?" +
      q
      .to_array()
      .map(fn(item) {
        let (k, v) = item
        k + "=" + v
      })
      .join("&")
    None => ""
  }
  let fragment_str = match fragment {
    Some(f) => "#" + f
    None => ""
  }
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
