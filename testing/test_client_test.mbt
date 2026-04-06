///|
async test "testing package: GET returns text" {
  let app = @crescent.Mocket()
  app.get_raw("/hello", fn(_) noraise { "Hello!" })
  let client = @testing.TestClient(app)
  let res = client.get("/hello")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "Hello!")
}

///|
async test "testing package: POST with json body" {
  let app = @crescent.Mocket()
  app.post("/echo", event => {
    let text : String = event.req.body()
    text
  })
  let client = @testing.TestClient(app)
  let res = client.post("/echo", body=b"hello world")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "hello world")
}

///|
async test "testing package: route params" {
  let app = @crescent.Mocket()
  app.get("/users/:id", event => {
    let id = event.require_param_int("id")
    @crescent.HttpResponse::ok().json_value(id)
  })
  let client = @testing.TestClient(app)
  let res = client.get("/users/42")
  assert_eq(res.status, OK)
}

///|
async test "testing package: 404 for missing route" {
  let app = @crescent.Mocket()
  app.get_raw("/exists", fn(_) noraise { "ok" })
  let client = @testing.TestClient(app)
  let res = client.get("/missing")
  assert_eq(res.status, NotFound)
}

///|
async test "testing package: middleware runs" {
  let app = @crescent.Mocket()
  app.use_middleware(@crescent.security_headers())
  app.get_raw("/test", fn(_) noraise { "ok" })
  let client = @testing.TestClient(app)
  let res = client.get("/test")
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
}

///|
async test "testing package: body_json parses typed response" {
  let app = @crescent.Mocket()
  app.get_raw("/data", fn(_) noraise {
    @crescent.HttpResponse::ok().json_value(
      ({ "name": "Alice", "age": 30 } : Json),
    )
  })
  let client = @testing.TestClient(app)
  let res = client.get("/data")
  let text = res.body_text()
  assert_true(text.contains("Alice"))
  assert_true(text.contains("30"))
}
