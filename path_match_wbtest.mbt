///|
test "find_route_for_method hits static route" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.find_route_for_method("GET", "/users") is Some(_), content="true")
}

///|
test "find_route_for_method misses nonexistent path" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(
    app.find_route_for_method("GET", "/posts") is Some(_),
    content="false",
  )
}

///|
test "find_route_for_method misses wrong method" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(
    app.find_route_for_method("POST", "/users") is Some(_),
    content="false",
  )
}

///|
test "find_route_for_method dynamic route extracts params" {
  let app = Mocket::new()
  app.get("/users/:id", fn(_event) noraise { "user" })
  match app.find_route_for_method("GET", "/users/123") {
    Some((_, params)) => inspect(params, content="{\"id\": \"123\"}")
    None => fail("expected route match")
  }
}

///|
test "find_route_for_method dynamic route with multiple params" {
  let app = Mocket::new()
  app.get("/users/:userId/posts/:postId", fn(_event) noraise { "user_post" })
  match app.find_route_for_method("GET", "/users/42/posts/99") {
    Some((_, params)) =>
      inspect(params, content="{\"userId\": \"42\", \"postId\": \"99\"}")
    None => fail("expected route match")
  }
}

///|
test "has_route_for_method returns true for registered route" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("GET", "/users"), content="true")
}

///|
test "has_route_for_method returns false for missing route" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("GET", "/posts"), content="false")
}

///|
test "has_route_for_method returns false for wrong method" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.has_route_for_method("DELETE", "/users"), content="false")
}

///|
test "has_route_for_method matches dynamic route" {
  let app = Mocket::new()
  app.get("/users/:id", fn(_event) noraise { "user" })
  inspect(app.has_route_for_method("GET", "/users/456"), content="true")
}

///|
test "allowed_methods includes HEAD for GET route" {
  let app = Mocket::new()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/test", false)
  inspect(methods, content="[\"GET\", \"HEAD\"]")
}

///|
test "allowed_methods with implicit OPTIONS" {
  let app = Mocket::new()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/test", true)
  inspect(methods, content="[\"GET\", \"HEAD\", \"OPTIONS\"]")
}

///|
test "allowed_methods multiple methods on same path" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "list" })
  app.post("/users", fn(_event) noraise { "create" })
  app.delete("/users", fn(_event) noraise { "remove" })
  let methods = app.allowed_methods("/users", false)
  inspect(methods, content="[\"GET\", \"HEAD\", \"POST\", \"DELETE\"]")
}

///|
test "allowed_methods with explicit OPTIONS handler" {
  let app = Mocket::new()
  app.get("/test", fn(_event) noraise { "ok" })
  app.options_raw("/test", fn(_event) noraise { "opts" })
  let methods = app.allowed_methods("/test", false)
  inspect(methods, content="[\"GET\", \"HEAD\", \"OPTIONS\"]")
}

///|
test "allowed_methods returns empty for unknown path" {
  let app = Mocket::new()
  app.get("/test", fn(_event) noraise { "ok" })
  let methods = app.allowed_methods("/unknown", false)
  inspect(methods, content="[]")
}

///|
test "allowed_methods no implicit OPTIONS when empty" {
  let app = Mocket::new()
  let methods = app.allowed_methods("/nothing", true)
  inspect(methods, content="[]")
}

///|
test "find_route returns method-specific route first" {
  let app = Mocket::new()
  app.get("/test", fn(_event) noraise { "get" })
  app.all_raw("/test", fn(_event) noraise { "all" })
  inspect(app.find_route("GET", "/test") is Some(_), content="true")
}

///|
test "find_route falls back to wildcard when method not matched" {
  let app = Mocket::new()
  app.all_raw("/any", fn(_event) noraise { "any" })
  inspect(app.find_route("DELETE", "/any") is Some(_), content="true")
}

///|
test "find_route returns None when no route matches" {
  let app = Mocket::new()
  app.get("/users", fn(_event) noraise { "users" })
  inspect(app.find_route("GET", "/missing") is Some(_), content="false")
}

///|
test "find_route wildcard dynamic route with params" {
  let app = Mocket::new()
  app.all_raw("/items/:id", fn(_event) noraise { "item" })
  match app.find_route("PATCH", "/items/77") {
    Some((_, params)) => inspect(params, content="{\"id\": \"77\"}")
    None => fail("expected wildcard dynamic route match")
  }
}

///|
test "find_ws_route static hit" {
  let app = Mocket::new()
  app.ws("/ws", fn(_event) {  })
  inspect(app.find_ws_route("/ws") is Some(_), content="true")
}

///|
test "find_ws_route dynamic hit" {
  let app = Mocket::new()
  app.ws("/ws/:room", fn(_event) {  })
  inspect(app.find_ws_route("/ws/lobby") is Some(_), content="true")
}

///|
test "find_ws_route miss" {
  let app = Mocket::new()
  app.ws("/ws", fn(_event) {  })
  inspect(app.find_ws_route("/other") is Some(_), content="false")
}
