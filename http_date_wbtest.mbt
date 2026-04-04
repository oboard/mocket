///|
test "format_http_date matches RFC 1123 samples" {
  assert_eq(format_http_date(0L), "Thu, 01 Jan 1970 00:00:00 GMT")
  assert_eq(format_http_date(951_827_696L), "Tue, 29 Feb 2000 12:34:56 GMT")
  assert_eq(format_http_date(1_709_251_199L), "Thu, 29 Feb 2024 23:59:59 GMT")
  assert_eq(format_http_date(2_147_483_647L), "Tue, 19 Jan 2038 03:14:07 GMT")
}

///|
test "parse_http_date accepts RFC 1123 samples and rejects invalid values" {
  assert_eq(parse_http_date("Thu, 01 Jan 1970 00:00:00 GMT"), Some(0L))
  assert_eq(
    parse_http_date("Tue, 29 Feb 2000 12:34:56 GMT"),
    Some(951_827_696L),
  )
  assert_eq(
    parse_http_date("Thu, 29 Feb 2024 23:59:59 GMT"),
    Some(1_709_251_199L),
  )
  assert_eq(parse_http_date("Thu, 31 Feb 2024 00:00:00 GMT"), None)
  assert_eq(parse_http_date("Thu, 29 Feb 2024 24:00:00 GMT"), None)
  assert_eq(parse_http_date("invalid"), None)
}
