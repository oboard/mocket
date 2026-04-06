///|
async test "request_id middleware generates unique ids" {
  let app = @crescent.Mocket()
  app.use_middleware(@crescent.request_id())
  app.get("/test", event => {
    let id = event.request_id()
    match id {
      Some(id) => "id:\{id}"
      None => "no-id"
    }
  })
  let client = @crescent.TestClient(app)
  let res1 = client.get("/test")
  let res2 = client.get("/test")
  // Both should have X-Request-Id
  assert_true(res1.headers.get("X-Request-Id") is Some(_))
  assert_true(res2.headers.get("X-Request-Id") is Some(_))
  // IDs should be different
  assert_true(
    res1.headers.get("X-Request-Id") != res2.headers.get("X-Request-Id"),
  )
  // Body should contain the ID
  assert_true(res1.body_text().has_prefix("id:req-"))
}

///|
async test "request_id middleware preserves existing id" {
  let app = @crescent.Mocket()
  app.use_middleware(@crescent.request_id())
  app.get("/test", event => {
    match event.request_id() {
      Some(id) => id
      None => "no-id"
    }
  })
  let client = @crescent.TestClient(app)
  let res = client.get("/test", headers={ "X-Request-Id": "custom-trace-123" })
  assert_eq(res.headers.get("X-Request-Id"), Some("custom-trace-123"))
  assert_eq(res.body_text(), "custom-trace-123")
}

///|
async test "request_id returns None without middleware" {
  let app = @crescent.Mocket()
  app.get("/test", event => {
    match event.request_id() {
      Some(id) => id
      None => "no-id"
    }
  })
  let client = @crescent.TestClient(app)
  let res = client.get("/test")
  assert_eq(res.body_text(), "no-id")
}
