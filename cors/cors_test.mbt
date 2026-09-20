///|
async test "credentialed wildcard CORS reflects the request origin" {
  let app = @mocket.App()
  app.use_middleware(handle_cors(credentials=true))
  app.get("/resource", _ => "ok")
  let response = @mocket.dispatch_http(
    app,
    "GET",
    "/resource",
    { "Origin": "https://app.example" },
    b"",
  )
  @test.assert_eq(
    response.headers.get("Access-Control-Allow-Origin"),
    Some("https://app.example"),
  )
  @test.assert_eq(
    response.headers.get("Access-Control-Allow-Credentials"),
    Some("true"),
  )
}

///|
async test "credentialed CORS does not emit wildcard without an Origin" {
  let app = @mocket.App()
  app.use_middleware(handle_cors(credentials=true))
  app.get("/resource", _ => "ok")
  let response = @mocket.dispatch_http(app, "GET", "/resource", {}, b"")
  @test.assert_eq(response.headers.get("Access-Control-Allow-Origin"), None)
  @test.assert_eq(
    response.headers.get("Access-Control-Allow-Credentials"),
    Some("true"),
  )
}

///|
async test "credentialed preflight reflects the request origin" {
  let app = @mocket.App()
  app.use_middleware(handle_cors(credentials=true))
  let response = @mocket.dispatch_http(
    app,
    "OPTIONS",
    "/resource",
    { "Origin": "https://app.example", "Access-Control-Request-Method": "POST" },
    b"",
  )
  @test.assert_eq(response.status_code.to_int(), 200)
  @test.assert_eq(
    response.headers.get("Access-Control-Allow-Origin"),
    Some("https://app.example"),
  )
}
