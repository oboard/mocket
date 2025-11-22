///|
test "url_decode" {
  let encoded = @encoding/utf8.encode("Hello%20World%21")
  let decoded = url_decode(encoded[:])
  assert_eq(decoded, "Hello World!")
}

///|
test "url_decode_plus" {
  let encoded = @encoding/utf8.encode("Hello+World")
  let decoded = url_decode(encoded[:])
  assert_eq(decoded, "Hello World")
}

///|
test "url_decode_utf8" {
  // %E4%BD%A0%E5%A5%BD = 你好
  let encoded = @encoding/utf8.encode("%E4%BD%A0%E5%A5%BD")
  let decoded = url_decode(encoded[:])
  assert_eq(decoded, "你好")
}

///|
test "form_encode" {
  let map = Map::new()
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
  let encoded = @encoding/utf8.encode("key=value&foo=bar%20baz")
  let map = parse_form_data(encoded[:])
  assert_eq(map.get("key"), Some("value"))
  assert_eq(map.get("foo"), Some("bar baz"))
}
