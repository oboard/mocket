///|
async test "direct string responder sets text content type" {
  let app = App()
  app.get("/text", _ => "hello")
  let response = dispatch_http(app, "GET", "/text", {}, b"")
  inspect(response.status_code.to_int(), content="200")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("text/plain; charset=utf-8"),
  )
  let body : String = response.read_body()
  @test.assert_eq(body, "hello")
}

///|
async test "direct json responder sets json content type" {
  let app = App()
  app.get("/json", _ => ({ "ok": true } : Json))
  let response = dispatch_http(app, "GET", "/json", {}, b"")
  inspect(response.status_code.to_int(), content="200")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("application/json; charset=utf-8"),
  )
  let body : Json = response.read_body()
  json_inspect(body, content={ "ok": true })
}

///|
async test "direct html responder sets html content type" {
  let app = App()
  app.get("/html", _ => html("<h1>Hello</h1>"))
  let response = dispatch_http(app, "GET", "/html", {}, b"")
  inspect(response.status_code.to_int(), content="200")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("text/html; charset=utf-8"),
  )
  let body : String = response.read_body()
  @test.assert_eq(body, "<h1>Hello</h1>")
}

///|
async test "custom status body infers text content type" {
  let app = App()
  app.get("/bad-request", _ => HttpResponse(BadRequest).body("Invalid JSON"))
  let response = dispatch_http(app, "GET", "/bad-request", {}, b"")
  inspect(response.status_code.to_int(), content="400")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("text/plain; charset=utf-8"),
  )
  let body : String = response.read_body()
  @test.assert_eq(body, "Invalid JSON")
}

///|
async test "custom status html body infers html content type" {
  let app = App()
  app.get("/not-found", _ => HttpResponse(NotFound).body(html("<h1>404</h1>")))
  let response = dispatch_http(app, "GET", "/not-found", {}, b"")
  inspect(response.status_code.to_int(), content="404")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("text/html; charset=utf-8"),
  )
  let body : String = response.read_body()
  @test.assert_eq(body, "<h1>404</h1>")
}

///|
async test "json response infers json content type" {
  let app = App()
  app.get("/created", _ => HttpResponse(Created).json({ "ok": true }))
  let response = dispatch_http(app, "GET", "/created", {}, b"")
  inspect(response.status_code.to_int(), content="201")
  @test.assert_eq(
    response.headers.get("Content-Type"),
    Some("application/json; charset=utf-8"),
  )
  let body : Json = response.read_body()
  json_inspect(body, content={ "ok": true })
}

///|
async test "form data responder writes a multipart body" {
  let app = App()
  let form = FormData::new({
    "title": {
      filename: None,
      content_type: None,
      data: @utf8.encode("MoonBit")[:],
    },
    "file": {
      filename: Some("hello.txt"),
      content_type: Some("text/plain"),
      data: @utf8.encode("hello")[:],
    },
  })
  app.get("/form", _ => form)
  let response = dispatch_http(app, "GET", "/form", {}, b"")
  guard response.headers.get("Content-Type") is Some(content_type) else {
    fail("missing multipart Content-Type")
  }
  guard content_type
    is [.. "multipart/form-data; boundary=----WebKitFormBoundary", .. boundary] else {
    fail("unexpected multipart boundary")
  }
  @test.assert_eq(boundary.length(), 24)
  let boundary = "----WebKitFormBoundary\{boundary}"
  let body : String = response.read_body()
  assert_true(body.has_prefix("--\{boundary}\r\n"))
  assert_true(
    body.contains(
      "Content-Disposition: form-data; name=\"title\"\r\n\r\nMoonBit\r\n",
    ),
  )
  assert_true(
    body.contains(
      "Content-Disposition: form-data; name=\"file\"; filename=\"hello.txt\"\r\nContent-Type: text/plain\r\n\r\nhello\r\n",
    ),
  )
  assert_true(body.has_suffix("--\{boundary}--\r\n"))
}

///|
async test "explicit content type wins over inferred body type" {
  let app = App()
  app.get("/custom-body", _ => {
    HttpResponse(OK, headers={ "Content-Type": "application/vnd.custom" }).body(
      "plain text",
    )
  })
  app.get("/custom-json", _ => {
    HttpResponse(OK, headers={ "Content-Type": "application/vnd.custom+json" }).json({
        "ok": true,
      },
    )
  })

  let body_response = dispatch_http(app, "GET", "/custom-body", {}, b"")
  @test.assert_eq(
    body_response.headers.get("Content-Type"),
    Some("application/vnd.custom"),
  )
  let body : String = body_response.read_body()
  @test.assert_eq(body, "plain text")

  let json_response = dispatch_http(app, "GET", "/custom-json", {}, b"")
  @test.assert_eq(
    json_response.headers.get("Content-Type"),
    Some("application/vnd.custom+json"),
  )
  let json : Json = json_response.read_body()
  json_inspect(json, content={ "ok": true })
}
