///|
test "url_decode" {
  let encoded = @utf8.encode("Hello%20World%21")
  let decoded = url_decode(encoded[:])
  @test.assert_eq(decoded, "Hello World!")
}

///|
test "url_decode_plus" {
  let encoded = @utf8.encode("Hello+World")
  let decoded = url_decode(encoded[:])
  @test.assert_eq(decoded, "Hello World")
}

///|
test "url_decode_utf8" {
  // %E4%BD%A0%E5%A5%BD = 你好
  let encoded = @utf8.encode("%E4%BD%A0%E5%A5%BD")
  let decoded = url_decode(encoded[:])
  @test.assert_eq(decoded, "你好")
}

///|
test "form_encode" {
  let map = Map([])
  map.set("key", "value")
  map.set("foo", "bar")
  let encoded = form_encode(map)
  // Order is not guaranteed in Map iteration, so we check if it contains parts
  // But Map iteration order might be deterministic in MoonBit?
  // Let's just check if it's one of the valid permutations
  let valid1 = "key=value&foo=bar"
  let valid2 = "foo=bar&key=value"
  assert_true(encoded == valid1 || encoded == valid2)
}

///|
test "parse_form_data" {
  let encoded = @utf8.encode("key=value&foo=bar%20baz")
  let map = parse_form_data(encoded[:])
  @test.assert_eq(map.get("key"), Some("value"))
  @test.assert_eq(map.get("foo"), Some("bar baz"))
}

///|
test "parse_multipart" {
  let boundary = "boundary"
  let body = "--boundary\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nvalue1\r\n--boundary\r\nContent-Disposition: form-data; name=\"field2\"; filename=\"example.txt\"\r\nContent-Type: text/plain\r\n\r\nvalue2\r\n--boundary--"
  let bytes = @utf8.encode(body)
  let parts = parse_multipart(bytes[:], boundary)
  @test.assert_eq(
    parts.get("field1").map(v => @utf8.decode(v.data) catch { _ => "" }),
    Some("value1"),
  )
  @test.assert_eq(parts.get("field1").bind(v => v.filename), None)
  @test.assert_eq(
    parts.get("field2").map(v => @utf8.decode(v.data) catch { _ => "" }),
    Some("value2"),
  )
  @test.assert_eq(
    parts.get("field2").bind(v => v.filename),
    Some("example.txt"),
  )
  @test.assert_eq(
    parts.get("field2").bind(v => v.content_type),
    Some("text/plain"),
  )
}

///|
test "parse_multipart preserves boundary-like binary payload" {
  let boundary = "boundary"
  let payload : Bytes = [
    0x00, b'a', b'\r', b'\n', b'-', b'-', b'b', b'o', b'u', b'n', b'd', b'a', b'r',
    b'y', b'x', 0xff,
  ]
  let body = []
  for
    byte in @utf8.encode(
      "--boundary\r\nContent-Disposition: form-data; name=field\r\n\r\n",
    ) {
    body.push(byte)
  }
  for byte in payload {
    body.push(byte)
  }
  for byte in @utf8.encode("\r\n--boundary--\r\n") {
    body.push(byte)
  }
  let parts = parse_multipart(Bytes::from_array(body)[:], boundary)
  @test.assert_eq(parts.get("field").map(v => v.data.to_owned()), Some(payload))
}

///|
test "parse_multipart accepts unquoted disposition parameters" {
  let body = "--boundary\r\nContent-Disposition: form-data; name=field; filename=file.txt\r\n\r\nvalue\r\n--boundary--\r\n"
  let parts = parse_multipart(@utf8.encode(body)[:], "boundary")
  @test.assert_eq(parts.get("field").bind(v => v.filename), Some("file.txt"))
  @test.assert_eq(
    parts.get("field").map(v => @utf8.decode(v.data)),
    Some("value"),
  )
}

///|
test "encode_multipart preserves binary data and sanitizes metadata" {
  let data : Bytes = [
    0x00, 0xff, b'\r', b'\n', b'-', b'-', b'b', b'o', b'u', b'n', b'd', b'a', b'r',
    b'y', b'x',
  ]
  let fields : Map[String, MultipartFormValue] = Map([])
  fields.set("field\r\nInjected: value", {
    filename: Some("file\r\nInjected: value"),
    content_type: Some("application/octet-stream\r\nInjected: value"),
    data: data[:],
  })
  let encoded = encode_multipart(fields, "boundary")
  let expected_headers = "Content-Disposition: form-data; name=\"fieldInjected: value\"; filename=\"fileInjected: value\"\r\nContent-Type: application/octet-streamInjected: value\r\n"
  assert_true(encoded.find(@utf8.encode(expected_headers)[:]) is Some(_))
  assert_true(encoded.find(@utf8.encode("\r\nInjected: value\r\n")[:]) is None)
  let parts = parse_multipart(encoded[:], "boundary")
  @test.assert_eq(
    parts.get("fieldInjected: value").map(v => v.data.to_owned()),
    Some(data),
  )
}
