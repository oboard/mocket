///|
test "find_route_for_method hits static route" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.find_route_for_method("GET", "/users") is Some(_), content="true")
}

///|
test "find_route_for_method misses nonexistent path" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(
    app.find_route_for_method("GET", "/posts") is Some(_),
    content="false",
  )
}

///|
test "find_route_for_method misses wrong method" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(
    app.find_route_for_method("POST", "/users") is Some(_),
    content="false",
  )
}

///|
test "find_route_for_method dynamic route extracts params" {
  let app = Mocket()
  app.get("/users/:id", fn(_event) noraise { "user" })
  match app.find_route_for_method("GET", "/users/123") {
    Some((_, params)) => inspect(params, content="{\"id\": \"123\"}")
    None => fail("expected route match")
  }
}

///|
test "find_route_for_method dynamic route with multiple params" {
  let app = Mocket()
  app.get("/users/:userId/posts/:postId", fn(_event) noraise { "user_post" })
  match app.find_route_for_method("GET", "/users/42/posts/99") {
    Some((_, params)) =>
      inspect(params, content="{\"userId\": \"42\", \"postId\": \"99\"}")
    None => fail("expected route match")
  }
}

///|
test "has_route_for_method returns true for registered route" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("GET", "/users"), content="true")
}

///|
test "has_route_for_method returns false for missing route" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("GET", "/posts"), content="false")
}

///|
test "has_route_for_method returns false for wrong method" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("DELETE", "/users"), content="false")
}

///|
test "has_route_for_method matches dynamic route" {
  let app = Mocket()
  app.get("/users/:id", fn(_event) noraise { "user" })
  inspect(app.has_route_for_method("GET", "/users/456"), content="true")
}

///|
test "allowed_methods includes HEAD for GET route" {
  let app = Mocket()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/test", false)
  inspect(methods, content="[\"GET\", \"HEAD\"]")
}

///|
test "allowed_methods with implicit OPTIONS" {
  let app = Mocket()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/test", true)
  inspect(methods, content="[\"GET\", \"HEAD\", \"OPTIONS\"]")
}

///|
test "allowed_methods multiple methods on same path" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "list" })
  app.post("/users", fn(_event) noraise { "create" })
  app.delete("/users", fn(_event) noraise { "remove" })
  let methods = app.allowed_methods("/users", false)
  inspect(methods, content="[\"GET\", \"HEAD\", \"POST\", \"DELETE\"]")
}

///|
test "allowed_methods with explicit OPTIONS handler" {
  let app = Mocket()
  app.get("/test", fn(_event) noraise { "ok" })
  app.options_raw("/test", fn(_event) noraise { "opts" })
  let methods = app.allowed_methods("/test", false)
  inspect(methods, content="[\"GET\", \"HEAD\", \"OPTIONS\"]")
}

///|
test "allowed_methods returns empty for unknown path" {
  let app = Mocket()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/unknown", false)
  inspect(methods, content="[]")
}

///|
test "allowed_methods no implicit OPTIONS when empty" {
  let app = Mocket()
  let methods = app.allowed_methods("/nothing", true)
  inspect(methods, content="[]")
}

///|
test "find_route returns method-specific route first" {
  let app = Mocket()
  app.get("/test", fn(_event) noraise { "get" })
  app.all_raw("/test", fn(_event) noraise { "all" })
  inspect(app.find_route("GET", "/test") is Some(_), content="true")
}

///|
test "find_route falls back to wildcard when method not matched" {
  let app = Mocket()
  app.all_raw("/any", fn(_event) noraise { "any" })
  inspect(app.find_route("DELETE", "/any") is Some(_), content="true")
}

///|
test "find_route returns None when no route matches" {
  let app = Mocket()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.find_route("GET", "/missing") is Some(_), content="false")
}

///|
test "find_route wildcard dynamic route with params" {
  let app = Mocket()
  app.all_raw("/items/:id", fn(_event) noraise { "item" })
  match app.find_route("PATCH", "/items/77") {
    Some((_, params)) => inspect(params, content="{\"id\": \"77\"}")
    None => fail("expected wildcard dynamic route match")
  }
}

///|
test "find_ws_route static hit" {
  let app = Mocket()
  app.ws("/ws", fn(_event) {  })
  inspect(app.find_ws_route("/ws") is Some(_), content="true")
}

///|
test "find_ws_route dynamic hit" {
  let app = Mocket()
  app.ws("/ws/:room", fn(_event) {  })
  inspect(app.find_ws_route("/ws/lobby") is Some(_), content="true")
}

///|
test "find_ws_route extracts params from dynamic path" {
  let app = Mocket()
  app.ws("/ws/:room", fn(_event) {  })
  match app.find_ws_route("/ws/lobby") {
    Some((_, params)) => {
      assert_eq(params.get("room").map(StringView::to_string), Some("lobby"))
    }
    None => fail("expected route match")
  }
}

///|
test "find_ws_route extracts multiple params" {
  let app = Mocket()
  app.ws("/ws/:room/user/:id", fn(_event) {  })
  match app.find_ws_route("/ws/lobby/user/42") {
    Some((_, params)) => {
      assert_eq(params.get("room").map(StringView::to_string), Some("lobby"))
      assert_eq(params.get("id").map(StringView::to_string), Some("42"))
    }
    None => fail("expected route match")
  }
}

///|
test "find_ws_route static returns empty params" {
  let app = Mocket()
  app.ws("/ws", fn(_event) {  })
  match app.find_ws_route("/ws") {
    Some((_, params)) => assert_eq(params.length(), 0)
    None => fail("expected route match")
  }
}

///|
test "find_ws_route miss" {
  let app = Mocket()
  app.ws("/ws", fn(_event) {  })
  inspect(app.find_ws_route("/other") is Some(_), content="false")
}

// -- CompiledRoute path matching tests
// (previously a separate match_path function; now exercises CompiledRoute directly)

///|
fn match_path(template : String, path : String) -> Map[String, StringView]? {
  CompiledRoute::compile(template).match_path(path)
}

///|
test "match_path: static path" {
  assert_eq(match_path("/api/users", "/api/users"), Some({}))
  assert_eq(match_path("/api/users", "/api/posts"), None)
  assert_eq(match_path("/", "/"), Some({}))
}

///|
test "match_path: named parameters" {
  assert_eq(match_path("/users/:id", "/users/123"), Some({ "id": "123" }))
  assert_eq(
    match_path("/users/:userId/posts/:postId", "/users/456/posts/789"),
    Some({ "userId": "456", "postId": "789" }),
  )
  assert_eq(match_path("/users/:id", "/users/123/extra"), None)
}

///|
test "match_path: single-level wildcard" {
  assert_eq(
    match_path("/files/*", "/files/document.pdf"),
    Some({ "_": "document.pdf" }),
  )
  assert_eq(match_path("/api/*/status", "/api/v1/status"), Some({ "_": "v1" }))
  assert_eq(match_path("/files/*", "/files/docs/readme.txt"), None)
}

///|
test "match_path: multi-level wildcard" {
  assert_eq(
    match_path("/static/**", "/static/css/main.css"),
    Some({ "_": "css/main.css" }),
  )
  assert_eq(
    match_path("/assets/**", "/assets/images/icons/user.png"),
    Some({ "_": "images/icons/user.png" }),
  )
  assert_eq(match_path("/api/v1/**", "/api/v1/"), Some({ "_": "" }))
  assert_eq(
    match_path("/files/**/meta", "/files/a/b/meta"),
    Some({ "_": "a/b" }),
  )
  assert_eq(match_path("/files/**/meta", "/files/a/b/raw"), None)
}

///|
test "match_path: mixed patterns" {
  let result = match_path("/users/:id/files/*", "/users/123/files/avatar.jpg")
  assert_eq(result, Some({ "id": "123", "_": "avatar.jpg" }))
  let result2 = match_path(
    "/projects/:projectId/**", "/projects/abc/src/main.mbt",
  )
  assert_eq(result2, Some({ "projectId": "abc", "_": "src/main.mbt" }))
}

///|
test "match_path: edge cases" {
  // Template shorter than path
  assert_eq(match_path("/api", "/api/users"), None)
  // Path shorter than template (non-wildcard)
  assert_eq(match_path("/api/users", "/api"), None)
  // Special chars in parameter
  assert_eq(
    match_path("/search/:query", "/search/hello%20world"),
    Some({ "query": "hello%20world" }),
  )
}
