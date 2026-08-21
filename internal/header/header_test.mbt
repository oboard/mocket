///|
test "sanitize_header_value/clean" {
  assert_eq(@header.sanitize_header_value("hello world"), "hello world")
}

///|
test "sanitize_header_value/cr" {
  assert_eq(@header.sanitize_header_value("foo\rbar"), "foobar")
}

///|
test "sanitize_header_value/lf" {
  assert_eq(@header.sanitize_header_value("foo\nbar"), "foobar")
}

///|
test "sanitize_header_value/crlf" {
  assert_eq(@header.sanitize_header_value("foo\r\nbar"), "foobar")
}

///|
test "sanitize_header_value/multiple" {
  assert_eq(@header.sanitize_header_value("a\rb\nc\r\nd"), "abcd")
}

///|
test "sanitize_header_value/injection_attempt" {
  assert_eq(
    @header.sanitize_header_value("ok\r\nX-Injected: 1"),
    "okX-Injected: 1",
  )
}

///|
test "sanitize_header_value/empty" {
  assert_eq(@header.sanitize_header_value(""), "")
}

///|
test "is_valid_header_name/valid" {
  assert_true(@header.is_valid_header_name("Content-Type"))
  assert_true(@header.is_valid_header_name("X-Custom-Header"))
  assert_true(@header.is_valid_header_name("Accept"))
  assert_true(@header.is_valid_header_name("x-lowercase"))
}

///|
test "is_valid_header_name/valid_special_chars" {
  assert_true(@header.is_valid_header_name("!#$%&'*+-.^_`|~"))
}

///|
test "is_valid_header_name/empty" {
  assert_false(@header.is_valid_header_name(""))
}

///|
test "is_valid_header_name/cr_lf" {
  assert_false(@header.is_valid_header_name("X-Bad\r\nInjected"))
  assert_false(@header.is_valid_header_name("X-Bad\rName"))
  assert_false(@header.is_valid_header_name("X-Bad\nName"))
}

///|
test "is_valid_header_name/space" {
  assert_false(@header.is_valid_header_name("Bad Name"))
}

///|
test "is_valid_header_name/colon" {
  assert_false(@header.is_valid_header_name("Bad:Name"))
}

///|
test "is_valid_header_name/parenthesis" {
  assert_false(@header.is_valid_header_name("Bad(Name)"))
}

///|
test "is_valid_header_name/at_sign" {
  assert_false(@header.is_valid_header_name("Bad@Name"))
}

///|
test "sanitize_header_value/cookie_injection" {
  assert_eq(
    @header.sanitize_header_value("session=abc\r\nSet-Cookie: evil=1"),
    "session=abcSet-Cookie: evil=1",
  )
}
