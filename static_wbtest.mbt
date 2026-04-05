///|
test "normalize_mount_path normalizes empty, root, and trailing slashes" {
  inspect(normalize_mount_path(""), content="/")
  inspect(normalize_mount_path("/"), content="/")
  inspect(normalize_mount_path("/api/"), content="/api")
  inspect(normalize_mount_path("/api"), content="/api")
}

///|
test "mounted_asset_id extracts asset id relative to mount path" {
  inspect(mounted_asset_id("/", "/"), content="")
  inspect(mounted_asset_id("/", "/hello.txt"), content="hello.txt")
  inspect(mounted_asset_id("/static", "/static"), content="")
  inspect(mounted_asset_id("/static", "/static/hello.txt"), content="hello.txt")
  inspect(
    mounted_asset_id("/static", "/static/sub/file.txt"),
    content="sub/file.txt",
  )
}

///|
test "parse_accept_encoding_token strips whitespace and quality parameter and lowercases" {
  inspect(parse_accept_encoding_token("gzip"), content="gzip")
  inspect(parse_accept_encoding_token("  gzip  "), content="gzip")
  inspect(parse_accept_encoding_token("gzip;q=0.8"), content="gzip")
  inspect(parse_accept_encoding_token("BR"), content="br")
}

///|
test "normalize_etag_token strips weak prefix and whitespace" {
  inspect(normalize_etag_token("\"abc\""), content="\"abc\"")
  inspect(normalize_etag_token("W/\"abc\""), content="\"abc\"")
  inspect(normalize_etag_token("w/\"abc\""), content="\"abc\"")
  inspect(normalize_etag_token("  \"abc\"  "), content="\"abc\"")
}

///|
test "if_none_match_matches checks single, wildcard, list, and weak etag" {
  // single match
  assert_eq(if_none_match_matches("\"abc\"", "\"abc\""), true)
  // wildcard
  assert_eq(if_none_match_matches("*", "\"abc\""), true)
  // comma-separated list with match
  assert_eq(if_none_match_matches("\"aaa\", \"abc\", \"zzz\"", "\"abc\""), true)
  // no match
  assert_eq(if_none_match_matches("\"aaa\", \"bbb\"", "\"abc\""), false)
  // weak etag in list
  assert_eq(if_none_match_matches("W/\"aaa\", W/\"abc\"", "\"abc\""), true)
}
