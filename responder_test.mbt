///|
async test "direct string responder sets text content type" {
  let app = new()
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
  let app = new()
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
  let app = new()
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
  let app = new()
  app.get("/bad-request", _ => {
    HttpResponse::new(BadRequest).body("Invalid JSON")
  })
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
  let app = new()
  app.get("/not-found", _ => {
    HttpResponse::new(NotFound).body(html("<h1>404</h1>"))
  })
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
  let app = new()
  app.get("/created", _ => HttpResponse::new(Created).json({ "ok": true }))
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
async test "explicit content type wins over inferred body type" {
  let app = new()
  app.get("/custom-body", _ => {
    HttpResponse::new(OK, headers={ "Content-Type": "application/vnd.custom" }).body(
      "plain text",
    )
  })
  app.get("/custom-json", _ => {
    HttpResponse::new(OK, headers={
      "Content-Type": "application/vnd.custom+json",
    }).json({ "ok": true })
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
