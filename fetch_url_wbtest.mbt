///|
test "resolve_fetch_url basic http" {
  let (proto, host, port, path) = resolve_fetch_url("http://example.com/foo")
  assert_true(proto is Http)
  assert_eq(host, "example.com")
  assert_eq(port, 80)
  assert_eq(path, "/foo")
}

///|
test "resolve_fetch_url with port" {
  let (proto, host, port, path) = resolve_fetch_url(
    "https://api.example.com:8443/v1/users",
  )
  assert_true(proto is Https)
  assert_eq(host, "api.example.com")
  assert_eq(port, 8443)
  assert_eq(path, "/v1/users")
}

///|
test "resolve_fetch_url with query string" {
  let (_proto, _host, _port, path) = resolve_fetch_url(
    "http://example.com/search?q=hello&lang=en",
  )
  assert_eq(path, "/search?q=hello&lang=en")
}

///|
test "resolve_fetch_url default path" {
  let (_proto, _host, _port, path) = resolve_fetch_url("http://example.com/")
  assert_eq(path, "/")
}

///|
test "resolve_fetch_url https default port" {
  let (_proto, _host, port, _path) = resolve_fetch_url("https://example.com/")
  assert_eq(port, 443)
}

///|
test "resolve_fetch_url IPv6 literal" {
  let (_proto, host, _port, _path) = resolve_fetch_url(
    "http://[::1]:8080/index",
  )
  // IPv6 host should be wrapped in brackets
  assert_eq(host, "[::1]")
}

///|
test "resolve_fetch_url rejects unsupported scheme" {
  let res = try? resolve_fetch_url("ftp://example.com/foo")
  assert_true(res is Err(_))
}

///|
test "resolve_fetch_url rejects invalid URL" {
  let res = try? resolve_fetch_url("not a url")
  assert_true(res is Err(_))
}

///|
test "resolve_fetch_url rejects empty host" {
  let res = try? resolve_fetch_url("http:///foo")
  assert_true(res is Err(_))
}

///|
test "resolve_fetch_url handles empty path with query" {
  // http://host?query (no path, just query) — used in some integration tests
  let (_proto, host, _port, path) = resolve_fetch_url(
    "http://127.0.0.1:4000?via=query",
  )
  assert_eq(host, "127.0.0.1")
  assert_eq(path, "/?via=query")
}

///|
test "resolve_fetch_url rejects ftp" {
  let res = try? resolve_fetch_url("ftp://example.com/")
  match res {
    Err(FetchError::RequestFailed(msg)) =>
      assert_true(msg.contains("unsupported protocol"))
    _ => fail("expected FetchError")
  }
}
