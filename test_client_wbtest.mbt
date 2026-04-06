///|
async test "test client GET returns text" {
  let app = new()
  app.get("/hello", fn(_) noraise { "Hello!" })
  let client = TestClient::new(app)
  let res = client.get("/hello")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "Hello!")
}

///|
async test "test client GET returns json" {
  let app = new()
  app.get("/data", fn(_) noraise { ({ "key": "value" } : Json) })
  let client = TestClient::new(app)
  let res = client.get("/data")
  assert_eq(res.status, OK)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
}

///|
async test "test client POST with body" {
  let app = new()
  app.post("/echo", fn(event) noraise {
    let text : String = event.req.body() catch { _ => "error" }
    text
  })
  let client = TestClient::new(app)
  let res = client.post("/echo", body=b"hello world")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "hello world")
}

///|
async test "test client route params" {
  let app = new()
  app.get("/users/:id", fn(event) noraise { event.param("id").unwrap_or("?") })
  let client = TestClient::new(app)
  let res = client.get("/users/42")
  assert_eq(res.status, OK)
  assert_eq(res.body_text(), "42")
}

///|
async test "test client 404 for missing route" {
  let app = new()
  app.get("/exists", fn(_) noraise { "ok" })
  let client = TestClient::new(app)
  let res = client.get("/missing")
  assert_eq(res.status, NotFound)
}

///|
async test "test client custom not found handler" {
  let app = new()
  app.set_not_found_handler(fn(_) noraise {
    HttpResponse::not_found().body("custom 404")
  })
  let client = TestClient::new(app)
  let res = client.get("/anything")
  assert_eq(res.status, NotFound)
  assert_eq(res.body_text(), "custom 404")
}

///|
async test "test client runs middleware" {
  let app = new()
  app.use_middleware(security_headers())
  app.get("/test", fn(_) noraise { "ok" })
  let client = TestClient::new(app)
  let res = client.get("/test")
  assert_eq(res.status, OK)
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
  assert_eq(res.headers.get("X-Frame-Options"), Some("DENY"))
}

///|
async test "test client with error handling handler" {
  let app = new()
  app.post("/users", event => {
    let _body : Json = event.req.json()
    "created"
  })
  let client = TestClient::new(app)
  // Valid request
  let res = client.post("/users", body=b"{\"name\":\"Alice\"}")
  assert_eq(res.status, OK)
  // Invalid JSON
  let res2 = client.post("/users", body=b"not json")
  assert_eq(res2.status, BadRequest)
}

///|
async test "test client method not allowed" {
  let app = new()
  app.get("/only-get", fn(_) noraise { "ok" })
  let client = TestClient::new(app)
  let res = client.post("/only-get")
  assert_eq(res.status, MethodNotAllowed)
}

///|
async test "test client PUT and DELETE" {
  let app = new()
  app.put("/item", fn(_) noraise { "updated" })
  app.delete("/item", fn(_) noraise { "deleted" })
  let client = TestClient::new(app)
  let res_put = client.put("/item")
  assert_eq(res_put.body_text(), "updated")
  let res_del = client.delete("/item")
  assert_eq(res_del.body_text(), "deleted")
}

///|
async test "test client with custom headers" {
  let app = new()
  app.get("/auth", fn(event) noraise {
    match event.req.get_header("authorization") {
      Some(token) => "token: " + token
      None => "no auth"
    }
  })
  let client = TestClient::new(app)
  let res = client.get("/auth")
  assert_eq(res.body_text(), "no auth")
  let res2 = client.get("/auth", headers={ "Authorization": "Bearer abc123" })
  assert_eq(res2.body_text(), "token: Bearer abc123")
}

///|
async test "test client with path-scoped middleware" {
  let order : Array[String] = []
  let app = new()
  app.use_middleware(
    (_event, next) => {
      order.push("api-mw")
      next()
    },
    base_path="/api",
  )
  app.get("/api/data", fn(_) noraise { "data" })
  app.get("/other", fn(_) noraise { "other" })
  let client = TestClient::new(app)
  // Should trigger middleware
  ignore(client.get("/api/data"))
  assert_eq(order.length(), 1)
  // Should NOT trigger middleware
  ignore(client.get("/other"))
  assert_eq(order.length(), 1)
}
