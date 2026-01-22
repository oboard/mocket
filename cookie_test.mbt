///|
test "CookieItem::to_string" {
  let item : CookieItem = {
    name: "session_id",
    value: "12345",
    max_age: Some(3600),
    path: Some("/"),
    domain: Some("example.com"),
    secure: Some(true),
    http_only: Some(true),
    same_site: Some(SameSiteNone),
  }
  let s = Show::to_string(item)
  inspect(
    s,
    content="session_id=12345; Max-Age=3600; Path=/; Domain=example.com; Secure; HttpOnly; SameSite=SameSiteNone",
  )
}

///|
test "parse_cookie" {
  let cookie_str = "name=value; name2=value2; name3=value3"
  let cookies = parse_cookie(cookie_str)
  assert_eq(cookies.get("name").map(fn(i) { i.value }), Some("value"))
  assert_eq(cookies.get("name2").map(fn(i) { i.value }), Some("value2"))
  assert_eq(cookies.get("name3").map(fn(i) { i.value }), Some("value3"))
}

///|
test "parse_cookie_with_attributes" {
  let cookie_str = "session_id=12345; Path=/; Domain=example.com; Max-Age=3600; Secure; HttpOnly; SameSite=Lax"
  let cookies = parse_cookie(cookie_str)
  match cookies.get("session_id") {
    Some(item) => {
      assert_eq(item.value, "12345")
      assert_eq(item.path, Some("/"))
      assert_eq(item.domain, Some("example.com"))
      assert_eq(item.max_age, Some(3600))
      assert_eq(item.secure, Some(true))
      assert_eq(item.http_only, Some(true))
      assert_eq(item.same_site, Some(Lax))
    }
    None => fail("Expected session_id cookie")
  }
}

///|
test "parse_cookie_multiple_with_attributes" {
  let cookie_str = "c1=v1; Path=/app; c2=v2; Secure; SameSite=Strict"
  let cookies = parse_cookie(cookie_str)
  match cookies.get("c1") {
    Some(item) => {
      assert_eq(item.value, "v1")
      assert_eq(item.path, Some("/app"))
      assert_eq(item.secure, None) // Should not have secure
    }
    None => fail("Expected c1")
  }
  match cookies.get("c2") {
    Some(item) => {
      assert_eq(item.value, "v2")
      assert_eq(item.secure, Some(true))
      assert_eq(item.same_site, Some(Strict))
      assert_eq(item.path, None) // Should not have path
    }
    None => fail("Expected c2")
  }
}

///|
test "parse_cookie_with_spaces" {
  let cookie_str = " name = value ; name2= value2 "
  let cookies = parse_cookie(cookie_str)
  assert_eq(cookies.get("name").map(fn(i) { i.value }), Some("value"))
  assert_eq(cookies.get("name2").map(fn(i) { i.value }), Some("value2"))
}

///|
test "parse_cookie_quoted" {
  let cookie_str = "name=\"value with spaces\"; name2=\"value2\""
  let cookies = parse_cookie(cookie_str)
  assert_eq(
    cookies.get("name").map(fn(i) { i.value }),
    Some("value with spaces"),
  )
  assert_eq(cookies.get("name2").map(fn(i) { i.value }), Some("value2"))
}

///|
test "parse_cookie_empty_value" {
  let cookie_str = "name=; name2="
  let cookies = parse_cookie(cookie_str)
  assert_eq(cookies.get("name").map(fn(i) { i.value }), Some(""))
  assert_eq(cookies.get("name2").map(fn(i) { i.value }), Some(""))
}

///|
test "parse_cookie_no_value" {
  let cookie_str = "name; name2"
  let cookies = parse_cookie(cookie_str)
  assert_eq(cookies.get("name").map(fn(i) { i.value }), Some(""))
  assert_eq(cookies.get("name2").map(fn(i) { i.value }), Some(""))
}

///|
test "parse_complex_cookie_string" {
  let cookie_str = "__stripe_mid=4e192e8c-7c22-4923-aaf1-6b174a77a43555136e; JSESSIONID=5C63BF22946D333F1079A0150ECABBCB; session_id=12345"
  let cookies = parse_cookie(cookie_str)
  assert_eq(
    cookies.get("__stripe_mid").map(fn(i) { i.value }),
    Some("4e192e8c-7c22-4923-aaf1-6b174a77a43555136e"),
  )
  assert_eq(cookies.get("session_id").map(fn(i) { i.value }), Some("12345"))
  assert_eq(
    cookies.get("JSESSIONID").map(fn(i) { i.value }),
    Some("5C63BF22946D333F1079A0150ECABBCB"),
  )
}
