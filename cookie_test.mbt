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

///|
test "get_cookie supports case-insensitive header lookup and delete_cookie expires values" {
  let req_lower = HttpRequest::{
    http_method: "GET",
    url: "/",
    headers: { "cookie": "session=abc123; theme=dark" },
    raw_body: b"",
  }
  match req_lower.get_cookie("session") {
    Some(cookie) => assert_eq(cookie.value, "abc123")
    None => fail("Expected session cookie")
  }

  let req_mixed = HttpRequest::{
    http_method: "GET",
    url: "/",
    headers: { "CoOkIe": "theme=dark" },
    raw_body: b"",
  }
  match req_mixed.get_cookie("theme") {
    Some(cookie) => assert_eq(cookie.value, "dark")
    None => fail("Expected theme cookie")
  }
  assert_eq(req_mixed.get_cookie("missing"), None)

  let res = HttpResponse::new(OK)
  res.delete_cookie("session")
  match res.cookies.get("session") {
    Some(cookie) => {
      assert_eq(cookie.value, "")
      assert_eq(cookie.max_age, Some(0))
    }
    None => fail("Expected deleted session cookie")
  }
}

///|
test "cookie_to_string joins cookies and invalid max-age falls back to none" {
  let cookies = [
    CookieItem::{
      name: "session",
      value: "abc123",
      max_age: None,
      path: Some("/"),
      domain: None,
      secure: Some(true),
      http_only: Some(true),
      same_site: Some(Lax),
    },
    CookieItem::{
      name: "theme",
      value: "dark",
      max_age: None,
      path: None,
      domain: None,
      secure: None,
      http_only: None,
      same_site: None,
    },
  ]
  inspect(
    cookie_to_string(cookies),
    content="session=abc123; Path=/; Secure; HttpOnly; SameSite=Lax;theme=dark",
  )

  let parsed = parse_cookie("session=abc123; Max-Age=oops")
  match parsed.get("session") {
    Some(cookie) => {
      assert_eq(cookie.value, "abc123")
      assert_eq(cookie.max_age, None)
    }
    None => fail("Expected parsed session cookie")
  }
}
