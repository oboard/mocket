///|
test "string responder sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let responder : &@mocket.Responder = "hello"
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"text/plain; charset=utf-8\")")
}

///|
test "string responder outputs utf8" {
  let buf = @buffer.new()
  let responder : &@mocket.Responder = "hello"
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|敨汬o
  ))
}

///|
test "string responder outputs utf8 with unicode" {
  let buf = @buffer.new()
  let responder : &@mocket.Responder = "你好"
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|뷤붥
  ))
}

///|
test "stringview responder sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let s : StringView = "world"[:]
  let responder : &@mocket.Responder = s
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"text/plain; charset=utf-8\")")
}

///|
test "stringview responder outputs utf8" {
  let buf = @buffer.new()
  let s : StringView = "world"[:]
  let responder : &@mocket.Responder = s
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|潷汲d
  ))
}

///|
test "json responder sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let j : Json = { "key": "value" }
  let responder : &@mocket.Responder = j
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"application/json; charset=utf-8\")")
}

///|
test "json responder outputs json string" {
  let buf = @buffer.new()
  let j : Json = { "key": "value" }
  let responder : &@mocket.Responder = j
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|≻敫≹∺慶畬≥}
  ))
}

///|
test "tojson responder sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let j : Json = { "a": 1 }
  let obj : &ToJson = j
  let responder : &@mocket.Responder = obj
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"application/json; charset=utf-8\")")
}

///|
test "tojson responder outputs json string" {
  let buf = @buffer.new()
  let j : Json = { "a": 1 }
  let obj : &ToJson = j
  let responder : &@mocket.Responder = obj
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|≻≡ㄺ}
  ))
}

///|
test "bytes responder sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let responder : &@mocket.Responder = b"\x01\x02\x03"
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"application/octet-stream\")")
}

///|
test "bytes responder outputs raw bytes" {
  let buf = @buffer.new()
  let responder : &@mocket.Responder = b"\x48\x65\x6c\x6c\x6f"
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|效汬o
  ))
}

///|
test "http response responder copies status code" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let source = @mocket.HttpResponse::new(@mocket.NotFound)
  let responder : &@mocket.Responder = source
  responder.options(res)
  inspect(res.status_code, content="NotFound")
}

///|
test "http response responder merges headers" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let source = @mocket.HttpResponse::new(
    @mocket.OK,
    headers={ "X-Custom": "test-value" },
  )
  let responder : &@mocket.Responder = source
  responder.options(res)
  inspect(res.headers.get("X-Custom"), content="Some(\"test-value\")")
}

///|
test "http response responder outputs raw body" {
  let buf = @buffer.new()
  let source = @mocket.HttpResponse::new(
    @mocket.OK,
    raw_body=b"response body",
  )
  let responder : &@mocket.Responder = source
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|敲灳湯敳戠摯y


  ))
}

///|
test "http request responder merges headers" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let req : @mocket.HttpRequest = {
    http_method: "GET",
    url: "/",
    headers: { "X-Forwarded": "proxy" },
    raw_body: b"",
  }
  let responder : &@mocket.Responder = req
  responder.options(res)
  inspect(res.headers.get("X-Forwarded"), content="Some(\"proxy\")")
}

///|
test "http request responder outputs raw body" {
  let buf = @buffer.new()
  let req : @mocket.HttpRequest = {
    http_method: "POST",
    url: "/data",
    headers: {},
    raw_body: b"request payload",
  }
  let responder : &@mocket.Responder = req
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|敲畱獥⁴慰汹慯d
  ))
}

///|
test "html helper sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let responder = @mocket.html("<h1>Hello</h1>")
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"text/html; charset=utf-8\")")
}

///|
test "html helper outputs html content" {
  let buf = @buffer.new()
  let responder = @mocket.html("<h1>Hello</h1>")
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|格㸱效汬㱯栯㸱
  ))
}

///|
test "text helper sets content type" {
  let res = @mocket.HttpResponse::new(@mocket.OK)
  let responder = @mocket.text("plain text")
  responder.options(res)
  inspect(res.headers.get("Content-Type"), content="Some(\"text/plain; charset=utf-8\")")
}

///|
test "text helper outputs text content" {
  let buf = @buffer.new()
  let responder = @mocket.text("plain text")
  responder.output(buf)
  inspect(buf.to_string(), content=(
    #|汰楡⁮整瑸
  ))
}
