///|
test "request_target_path extracts path from plain path" {
  inspect(request_target_path("/"), content="/")
  inspect(request_target_path("/index.html"), content="/index.html")
  inspect(request_target_path("/a/b/c"), content="/a/b/c")
}

///|
test "request_target_path strips query string" {
  inspect(request_target_path("/search?q=hello"), content="/search")
  inspect(request_target_path("/?key=val"), content="/")
  inspect(request_target_path("/a/b?x=1&y=2"), content="/a/b")
}

///|
test "request_target_path strips fragment" {
  inspect(request_target_path("/page#section"), content="/page")
  inspect(request_target_path("/#top"), content="/")
}

///|
test "request_target_path strips query and fragment" {
  inspect(request_target_path("/page?q=1#frag"), content="/page")
  inspect(request_target_path("/a/b?x=1&y=2#z"), content="/a/b")
}

///|
test "request_target_path with fragment before query uses earliest delimiter" {
  // '#' appears before '?' so path ends at '#'
  inspect(request_target_path("/page#frag?q=1"), content="/page")
}

///|
test "request_target_path with empty path" {
  inspect(request_target_path(""), content="")
}

///|
test "request_target_query_string returns None for plain paths" {
  assert_eq(request_target_query_string("/"), None)
  assert_eq(request_target_query_string("/index.html"), None)
  assert_eq(request_target_query_string("/a/b/c"), None)
}

///|
test "request_target_query_string extracts query" {
  assert_eq(request_target_query_string("/search?q=hello"), Some("q=hello"))
  assert_eq(request_target_query_string("/?key=val"), Some("key=val"))
  assert_eq(
    request_target_query_string("/a/b?x=1&y=2"),
    Some("x=1&y=2"),
  )
}

///|
test "request_target_query_string extracts query before fragment" {
  assert_eq(request_target_query_string("/page?q=1#frag"), Some("q=1"))
  assert_eq(
    request_target_query_string("/a?x=1&y=2#z"),
    Some("x=1&y=2"),
  )
}

///|
test "request_target_query_string returns None for fragment-only" {
  assert_eq(request_target_query_string("/page#section"), None)
  assert_eq(request_target_query_string("/#top"), None)
}

///|
test "request_target_query_string with fragment before query" {
  // '#' at index 5, '?' at index 10 => '?' exists but fragment is before it
  // The function finds '?' at index 10, then finds '#' at index 5 which is
  // NOT > query_start, so end stays at string length, returning everything
  // after '?'
  assert_eq(request_target_query_string("/page#frag?q=1"), Some("q=1"))
}

///|
test "request_target_query_string with empty query" {
  assert_eq(request_target_query_string("/page?"), Some(""))
  assert_eq(request_target_query_string("/page?#frag"), Some(""))
}

///|
test "path_scope_matches root scope matches everything" {
  assert_eq(path_scope_matches("/", "/"), true)
  assert_eq(path_scope_matches("/", "/anything"), true)
  assert_eq(path_scope_matches("/", "/a/b/c"), true)
}

///|
test "path_scope_matches exact match" {
  assert_eq(path_scope_matches("/api", "/api"), true)
  assert_eq(path_scope_matches("/a/b", "/a/b"), true)
}

///|
test "path_scope_matches prefix with segment boundary" {
  assert_eq(path_scope_matches("/api", "/api/users"), true)
  assert_eq(path_scope_matches("/api", "/api/users/123"), true)
  assert_eq(path_scope_matches("/a/b", "/a/b/c"), true)
}

///|
test "path_scope_matches rejects non-segment-boundary prefix" {
  // "/api" must NOT match "/apis" -- no '/' after the prefix
  assert_eq(path_scope_matches("/api", "/apis"), false)
  assert_eq(path_scope_matches("/api", "/apiversion"), false)
  assert_eq(path_scope_matches("/app", "/application"), false)
}

///|
test "path_scope_matches rejects completely different paths" {
  assert_eq(path_scope_matches("/api", "/web"), false)
  assert_eq(path_scope_matches("/api", "/"), false)
  assert_eq(path_scope_matches("/a/b", "/a/c"), false)
}
