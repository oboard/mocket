///|
test "native request body limit helpers handle int max boundaries" {
  let max_int = 2_147_483_647
  inspect(next_native_request_body_chunk_size(max_int, 0), content="1024")
  inspect(
    native_request_body_chunk_exceeds_limit(max_int, max_int, 1),
    content="true",
  )
  inspect(
    native_request_body_chunk_exceeds_limit(max_int, max_int - 1, 1),
    content="false",
  )
}

///|
test "request_method_to_string converts all HTTP methods" {
  inspect(request_method_to_string(Get), content="GET")
  inspect(request_method_to_string(Head), content="HEAD")
  inspect(request_method_to_string(Post), content="POST")
  inspect(request_method_to_string(Put), content="PUT")
  inspect(request_method_to_string(Delete), content="DELETE")
  inspect(request_method_to_string(Connect), content="CONNECT")
  inspect(request_method_to_string(Options), content="OPTIONS")
  inspect(request_method_to_string(Trace), content="TRACE")
  inspect(request_method_to_string(Patch), content="PATCH")
}

///|
test "append_cookie_headers with empty cookies does nothing" {
  let headers : Map[String, String] = {}
  let cookies : Map[String, CookieItem] = {}
  append_cookie_headers(headers, cookies)
  inspect(headers.contains("Set-Cookie"), content="false")
}

///|
test "append_cookie_headers with single cookie sets header" {
  let headers : Map[String, String] = {}
  let cookies : Map[String, CookieItem] = {}
  cookies.set("session", {
    name: "session",
    value: "abc123",
    max_age: None,
    path: None,
    domain: None,
    secure: None,
    http_only: None,
    same_site: None,
  })
  append_cookie_headers(headers, cookies)
  inspect(
    headers.get("Set-Cookie"),
    content=(
      #|Some("session=abc123")
    ),
  )
}

///|
test "append_cookie_headers with multiple cookies joins with CRLF Set-Cookie" {
  let headers : Map[String, String] = {}
  let cookies : Map[String, CookieItem] = {}
  cookies.set("a", {
    name: "a",
    value: "1",
    max_age: None,
    path: None,
    domain: None,
    secure: None,
    http_only: None,
    same_site: None,
  })
  cookies.set("b", {
    name: "b",
    value: "2",
    max_age: None,
    path: None,
    domain: None,
    secure: None,
    http_only: None,
    same_site: None,
  })
  append_cookie_headers(headers, cookies)
  inspect(
    headers.get("Set-Cookie"),
    content=(
      #|Some("a=1\r\nSet-Cookie: b=2")
    ),
  )
}

///|
test "header_contains_token_case_insensitive finds token in comma-separated list" {
  let headers : Map[String, String] = { "Connection": "keep-alive, Upgrade" }
  inspect(
    header_contains_token_case_insensitive(headers, "Connection", "upgrade"),
    content="true",
  )
}

///|
test "header_contains_token_case_insensitive returns false when token not found" {
  let headers : Map[String, String] = { "Connection": "keep-alive" }
  inspect(
    header_contains_token_case_insensitive(headers, "Connection", "upgrade"),
    content="false",
  )
}

///|
test "header_contains_token_case_insensitive is case insensitive on header name" {
  let headers : Map[String, String] = { "CONNECTION": "Upgrade" }
  inspect(
    header_contains_token_case_insensitive(headers, "connection", "upgrade"),
    content="true",
  )
}

///|
test "header_contains_token_case_insensitive returns false for missing header" {
  let headers : Map[String, String] = {}
  inspect(
    header_contains_token_case_insensitive(headers, "Connection", "upgrade"),
    content="false",
  )
}

///|
test "is_websocket_upgrade_request returns true with both headers" {
  let request : @http.Request = {
    meth: Get,
    path: "/",
    headers: { "Connection": "upgrade", "Upgrade": "websocket" },
  }
  inspect(is_websocket_upgrade_request(request), content="true")
}

///|
test "is_websocket_upgrade_request returns false without Connection header" {
  let request : @http.Request = {
    meth: Get,
    path: "/",
    headers: { "Upgrade": "websocket" },
  }
  inspect(is_websocket_upgrade_request(request), content="false")
}

///|
test "is_websocket_upgrade_request returns false without Upgrade header" {
  let request : @http.Request = {
    meth: Get,
    path: "/",
    headers: { "Connection": "upgrade" },
  }
  inspect(is_websocket_upgrade_request(request), content="false")
}

///|
test "is_websocket_upgrade_request returns false with empty headers" {
  let request : @http.Request = { meth: Get, path: "/", headers: {} }
  inspect(is_websocket_upgrade_request(request), content="false")
}

///|
test "allow_header_value joins methods with comma and space" {
  inspect(allow_header_value(["GET", "POST", "PUT"]), content="GET, POST, PUT")
}

///|
test "allow_header_value with single method" {
  inspect(allow_header_value(["GET"]), content="GET")
}

///|
test "allow_header_value with empty array" {
  inspect(allow_header_value([]), content="")
}

///|
test "next_native_request_body_chunk_size returns 1024 when remaining >= 1024" {
  inspect(next_native_request_body_chunk_size(2048, 0), content="1024")
  inspect(next_native_request_body_chunk_size(2048, 1024), content="1024")
  inspect(next_native_request_body_chunk_size(4096, 2000), content="1024")
}

///|
test "next_native_request_body_chunk_size returns remaining + 1 when remaining < 1024" {
  inspect(next_native_request_body_chunk_size(1000, 0), content="1001")
  inspect(next_native_request_body_chunk_size(2048, 1500), content="549")
  inspect(next_native_request_body_chunk_size(100, 99), content="2")
  inspect(next_native_request_body_chunk_size(100, 100), content="1")
}

///|
test "native_request_body_chunk_exceeds_limit returns true when chunk exceeds remaining" {
  inspect(native_request_body_chunk_exceeds_limit(100, 90, 11), content="true")
  inspect(native_request_body_chunk_exceeds_limit(100, 100, 1), content="true")
}

///|
test "native_request_body_chunk_exceeds_limit returns false when chunk fits" {
  inspect(native_request_body_chunk_exceeds_limit(100, 90, 10), content="false")
  inspect(native_request_body_chunk_exceeds_limit(100, 0, 100), content="false")
  inspect(native_request_body_chunk_exceeds_limit(100, 50, 1), content="false")
}
