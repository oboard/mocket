///|
test "header_name_matches exact match" {
  assert_eq(header_name_matches("Content-Type", "Content-Type"), true)
  assert_eq(header_name_matches("host", "host"), true)
}

///|
test "header_name_matches case insensitive" {
  assert_eq(header_name_matches("Content-Type", "content-type"), true)
  assert_eq(header_name_matches("HOST", "host"), true)
  assert_eq(header_name_matches("Accept-Encoding", "ACCEPT-ENCODING"), true)
}

///|
test "header_name_matches non-matching" {
  assert_eq(header_name_matches("Content-Type", "Accept"), false)
  assert_eq(header_name_matches("Host", "Hos"), false)
  assert_eq(header_name_matches("", "Host"), false)
  assert_eq(header_name_matches("Host", ""), false)
}

///|
test "header_name_matches empty strings" {
  assert_eq(header_name_matches("", ""), true)
}

///|
test "find_header_key_case_insensitive finds exact key" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  inspect(
    find_header_key_case_insensitive(headers, "Content-Type"),
    content="Some(\"Content-Type\")",
  )
}

///|
test "find_header_key_case_insensitive finds key case-insensitively" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  inspect(
    find_header_key_case_insensitive(headers, "content-type"),
    content="Some(\"Content-Type\")",
  )
}

///|
test "find_header_key_case_insensitive returns None for missing key" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  inspect(find_header_key_case_insensitive(headers, "Accept"), content="None")
}

///|
test "find_header_key_case_insensitive empty map" {
  let headers : Map[String, String] = {}
  inspect(find_header_key_case_insensitive(headers, "Host"), content="None")
}

///|
test "get_header_case_insensitive returns value" {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Host": "example.com",
  }
  inspect(
    get_header_case_insensitive(headers, "content-type"),
    content="Some(\"application/json\")",
  )
  inspect(
    get_header_case_insensitive(headers, "HOST"),
    content="Some(\"example.com\")",
  )
}

///|
test "get_header_case_insensitive returns None for missing" {
  let headers : Map[String, String] = { "Host": "example.com" }
  inspect(get_header_case_insensitive(headers, "Accept"), content="None")
}

///|
test "get_header_case_insensitive empty map" {
  let headers : Map[String, String] = {}
  inspect(get_header_case_insensitive(headers, "Content-Type"), content="None")
}

///|
test "has_header_case_insensitive finds present header" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  assert_eq(has_header_case_insensitive(headers, "Content-Type"), true)
  assert_eq(has_header_case_insensitive(headers, "content-type"), true)
  assert_eq(has_header_case_insensitive(headers, "CONTENT-TYPE"), true)
}

///|
test "has_header_case_insensitive returns false for missing" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  assert_eq(has_header_case_insensitive(headers, "Accept"), false)
}

///|
test "has_header_case_insensitive empty map" {
  let headers : Map[String, String] = {}
  assert_eq(has_header_case_insensitive(headers, "Host"), false)
}

///|
test "set_header_case_insensitive adds new header" {
  let headers : Map[String, String] = {}
  set_header_case_insensitive(headers, "Content-Type", "text/html")
  inspect(headers.get("Content-Type"), content="Some(\"text/html\")")
}

///|
test "set_header_case_insensitive overwrites existing exact key" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  set_header_case_insensitive(headers, "Content-Type", "application/json")
  inspect(headers.get("Content-Type"), content="Some(\"application/json\")")
  assert_eq(headers.length(), 1)
}

///|
test "set_header_case_insensitive overwrites with different case and replaces key" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  set_header_case_insensitive(headers, "content-type", "application/json")
  // The old key should be removed and replaced with the new casing
  inspect(headers.get("Content-Type"), content="None")
  inspect(headers.get("content-type"), content="Some(\"application/json\")")
  assert_eq(headers.length(), 1)
}

///|
test "set_header_case_insensitive with multiple headers" {
  let headers : Map[String, String] = {
    "Host": "example.com",
    "Accept": "text/html",
  }
  set_header_case_insensitive(headers, "host", "other.com")
  inspect(headers.get("host"), content="Some(\"other.com\")")
  // Accept should remain untouched
  inspect(headers.get("Accept"), content="Some(\"text/html\")")
}

///|
test "set_missing_header_case_insensitive adds when absent" {
  let headers : Map[String, String] = {}
  set_missing_header_case_insensitive(headers, "Content-Type", "text/html")
  inspect(headers.get("Content-Type"), content="Some(\"text/html\")")
}

///|
test "set_missing_header_case_insensitive does not overwrite existing exact" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  set_missing_header_case_insensitive(
    headers, "Content-Type", "application/json",
  )
  inspect(headers.get("Content-Type"), content="Some(\"text/html\")")
}

///|
test "set_missing_header_case_insensitive does not overwrite case-insensitive match" {
  let headers : Map[String, String] = { "Content-Type": "text/html" }
  set_missing_header_case_insensitive(
    headers, "content-type", "application/json",
  )
  // Original value and key preserved
  inspect(headers.get("Content-Type"), content="Some(\"text/html\")")
  assert_eq(headers.length(), 1)
}

///|
test "set_missing_header_case_insensitive adds multiple distinct headers" {
  let headers : Map[String, String] = {}
  set_missing_header_case_insensitive(headers, "Host", "example.com")
  set_missing_header_case_insensitive(headers, "Accept", "text/html")
  assert_eq(headers.length(), 2)
  inspect(headers.get("Host"), content="Some(\"example.com\")")
  inspect(headers.get("Accept"), content="Some(\"text/html\")")
}

///|
test "merge_headers_case_insensitive into empty target" {
  let target : Map[String, String] = {}
  let source : Map[String, String] = {
    "Host": "example.com",
    "Accept": "text/html",
  }
  merge_headers_case_insensitive(target, source)
  assert_eq(target.length(), 2)
  inspect(target.get("Host"), content="Some(\"example.com\")")
  inspect(target.get("Accept"), content="Some(\"text/html\")")
}

///|
test "merge_headers_case_insensitive from empty source" {
  let target : Map[String, String] = { "Host": "example.com" }
  let source : Map[String, String] = {}
  merge_headers_case_insensitive(target, source)
  assert_eq(target.length(), 1)
  inspect(target.get("Host"), content="Some(\"example.com\")")
}

///|
test "merge_headers_case_insensitive overwrites existing case-insensitive" {
  let target : Map[String, String] = { "Content-Type": "text/html" }
  let source : Map[String, String] = { "content-type": "application/json" }
  merge_headers_case_insensitive(target, source)
  assert_eq(target.length(), 1)
  inspect(target.get("content-type"), content="Some(\"application/json\")")
}

///|
test "merge_headers_case_insensitive adds new and overwrites existing" {
  let target : Map[String, String] = {
    "Host": "example.com",
    "Accept": "text/html",
  }
  let source : Map[String, String] = {
    "host": "other.com",
    "Content-Type": "application/json",
  }
  merge_headers_case_insensitive(target, source)
  assert_eq(target.length(), 3)
  inspect(target.get("host"), content="Some(\"other.com\")")
  inspect(target.get("Accept"), content="Some(\"text/html\")")
  inspect(target.get("Content-Type"), content="Some(\"application/json\")")
}
