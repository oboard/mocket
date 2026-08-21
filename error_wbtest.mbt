///|
suberror TestRequestError {
  TestRequestError(String)
} derive(Debug)

///|
async test "dispatch converts unhandled handler errors to 500" {
  let app = new()
  app.get("/boom", _ => raise TestRequestError("boom"))
  let response = dispatch_http(app, "GET", "/boom", {}, b"")
  inspect(response.status_code.to_int(), content="500")
  let body : String = response.read_body()
  assert_true(body.length() > 0)
}

///|
async test "dispatch uses custom error handler" {
  let app = new()
  let log : Array[String] = []
  app.on_error((event, err) => {
    log.push("\{event.req.http_method} \{event.req.url}: \{err}")
    HttpResponse::new(Custom(599)).body("custom")
  })
  app.post("/custom", _ => raise TestRequestError("custom"))

  let response = dispatch_http(app, "POST", "/custom", {}, b"")
  inspect(response.status_code.to_int(), content="599")
  let body : String = response.read_body()
  @test.assert_eq(body, "custom")
  @test.assert_eq(log.length(), 1)
  assert_true(log[0].contains("POST /custom"))
  assert_true(log[0].contains("custom"))
}

///|
async test "handlers can still catch errors locally" {
  let app = new()
  app.get("/local", _ => {
    let text = try {
      raise TestRequestError("local")
    } catch {
      TestRequestError(msg) => msg
    }
    text
  })

  let response = dispatch_http(app, "GET", "/local", {}, b"")
  inspect(response.status_code.to_int(), content="200")
  let body : String = response.read_body()
  @test.assert_eq(body, "local")
}
