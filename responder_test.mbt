///|
test "string responder sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let responder : &@crescent.Responder = "hello"
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"text/plain; charset=utf-8\")",
  )
}

///|
test "string responder outputs utf8" {
  let buf = @buffer.new()
  let responder : &@crescent.Responder = "hello"
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("hello"))
}

///|
test "string responder outputs utf8 with unicode" {
  let buf = @buffer.new()
  let responder : &@crescent.Responder = "\u{4f60}\u{597d}"
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("\u{4f60}\u{597d}"))
}

///|
test "stringview responder sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let s : StringView = "world"[:]
  let responder : &@crescent.Responder = s
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"text/plain; charset=utf-8\")",
  )
}

///|
test "stringview responder outputs utf8" {
  let buf = @buffer.new()
  let s : StringView = "world"[:]
  let responder : &@crescent.Responder = s
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("world"))
}

///|
test "json responder sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let j : Json = { "key": "value" }
  let responder : &@crescent.Responder = j
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
}

///|
test "json responder outputs json string" {
  let buf = @buffer.new()
  let j : Json = { "key": "value" }
  let responder : &@crescent.Responder = j
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("{\"key\":\"value\"}"))
}

///|
test "tojson responder sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let j : Json = { "a": 1 }
  let obj : &ToJson = j
  let responder : &@crescent.Responder = obj
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
}

///|
test "tojson responder outputs json string" {
  let buf = @buffer.new()
  let j : Json = { "a": 1 }
  let obj : &ToJson = j
  let responder : &@crescent.Responder = obj
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("{\"a\":1}"))
}

///|
test "bytes responder sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let responder : &@crescent.Responder = b"\x01\x02\x03"
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/octet-stream\")",
  )
}

///|
test "bytes responder outputs raw bytes" {
  let buf = @buffer.new()
  let responder : &@crescent.Responder = b"\x48\x65\x6c\x6c\x6f"
  responder.output(buf)
  assert_eq(buf.contents(), b"\x48\x65\x6c\x6c\x6f")
}

///|
test "http response responder copies status code" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let source = @crescent.HttpResponse::new(@crescent.NotFound)
  let responder : &@crescent.Responder = source
  responder.options(res)
  inspect(res.status_code, content="NotFound")
}

///|
test "http response responder merges headers" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let source = @crescent.HttpResponse::new(@crescent.OK, headers={
    "X-Custom": "test-value",
  })
  let responder : &@crescent.Responder = source
  responder.options(res)
  inspect(res.headers.get("X-Custom"), content="Some(\"test-value\")")
}

///|
test "http response responder outputs raw body" {
  let buf = @buffer.new()
  let source = @crescent.HttpResponse::new(
    @crescent.OK,
    raw_body=b"response body",
  )
  let responder : &@crescent.Responder = source
  responder.output(buf)
  assert_eq(buf.contents(), b"response body")
}

///|
test "http request responder merges headers" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let req = @crescent.HttpRequest::new(
    @crescent.Get,
    "/",
    { "X-Forwarded": "proxy" },
    raw_body=b"",
  )
  let responder : &@crescent.Responder = req
  responder.options(res)
  inspect(res.headers.get("X-Forwarded"), content="Some(\"proxy\")")
}

///|
test "http request responder outputs raw body" {
  let buf = @buffer.new()
  let req = @crescent.HttpRequest::new(
    @crescent.Post,
    "/data",
    {},
    raw_body=b"request payload",
  )
  let responder : &@crescent.Responder = req
  responder.output(buf)
  assert_eq(buf.contents(), b"request payload")
}

///|
test "html helper sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let responder = @crescent.html("<h1>Hello</h1>")
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"text/html; charset=utf-8\")",
  )
}

///|
test "html helper outputs html content" {
  let buf = @buffer.new()
  let responder = @crescent.html("<h1>Hello</h1>")
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("<h1>Hello</h1>"))
}

///|
test "text helper sets content type" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  let responder = @crescent.text("plain text")
  responder.options(res)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"text/plain; charset=utf-8\")",
  )
}

///|
test "text helper outputs text content" {
  let buf = @buffer.new()
  let responder = @crescent.text("plain text")
  responder.output(buf)
  assert_eq(buf.contents(), @utf8.encode("plain text"))
}
