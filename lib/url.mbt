pub struct URL {
  protocol : String?
  host : String?
  port : Int?
  path : String
  query : Map[String, String]?
  fragment : String?
}

pub fn URL::parse(rawUrl : String) -> URL {
  let url = rawUrl.trim_space()
  let scheme_end = url.index_of("://")
  if scheme_end == -1 {
    return {
      protocol: None,
      host: None,
      port: None,
      path: url,
      query: None,
      fragment: None,
    }
  }
  let fragment_start = url.index_of("#")
  let query_start = url.index_of("?")
  let query_end = if fragment_start != -1 {
    fragment_start
  } else {
    url.length()
  }
  let port_start = url.index_of(":", from=scheme_end + 3)
  let port_end = if port_start != -1 {
    url.index_of("/", from=port_start)
  } else {
    url.index_of("/", from=scheme_end + 3)
  }
  let protocol = if scheme_end != -1 {
    Some(url.substring(start=0, end=scheme_end))
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
    Some(url.substring(start=host_start, end=host_end))
  } else {
    None
  }
  let port_str = url.substring(start=port_start + 1, end=port_end)
  let port = if port_str.length() > 0 {
    try {
      Some(@strconv.parse_int!(port_str))
    } catch {
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
  let path = url.substring(start=path_start, end=path_end)
  let query = if query_start != -1 {
    let query_str = url.substring(start=query_start + 1, end=query_end)
    let query_array = query_str.split("&")
    let query_map = query_array.map(
        fn(s) {
          let array = s.split("=")
          let key = array[0]
          let value = array[1]
          return (key, value)
        },
      )
      |> Map::from_array
    Some(query_map)
  } else {
    None
  }
  let fragment = if fragment_start != -1 {
    Some(url.substring(start=fragment_start + 1, end=url.length()))
  } else {
    None
  }
  return { protocol, host, port, path, query, fragment }
}

pub fn URL::output(self : URL, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

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
      "?" + q.to_array().map(
        fn(item) {
          let (k, v) = item
          k + "=" + v
        },
      ).join("&")
    None => ""
  }
  let fragment_str = match fragment {
    Some(f) => "#" + f
    None => ""
  }
  protocol + host + port_str + path + query_str + fragment_str
}

test "parse_url" {
  let url = "https://www.example.com:8080/path/to/resource?name=ferret&color=purple#section1"
  let result = URL::parse(url)
  println(url)
  println(result)
  inspect!(
    result,
    content="https://www.example.com:8080/path/to/resource?name=ferret&color=purple#section1",
  )
}
