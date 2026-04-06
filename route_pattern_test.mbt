///|
test "compiled route: static path matching" {
  let route = @crescent.CompiledRoute::compile("/api/users")
  assert_true(route.is_static)
  assert_eq(route.match_path("/api/users"), Some({}))
  assert_eq(route.match_path("/api/posts"), None)
}

///|
test "compiled route: named parameter" {
  let route = @crescent.CompiledRoute::compile("/users/:id")
  assert_true(route.is_static == false)
  assert_eq(route.match_path("/users/123"), Some({ "id": "123" }))
  assert_eq(route.match_path("/users/123/extra"), None)
}

///|
test "compiled route: multiple parameters" {
  let route = @crescent.CompiledRoute::compile("/users/:userId/posts/:postId")
  assert_eq(
    route.match_path("/users/456/posts/789"),
    Some({ "userId": "456", "postId": "789" }),
  )
}

///|
test "compiled route: single wildcard" {
  let route = @crescent.CompiledRoute::compile("/files/*")
  assert_eq(
    route.match_path("/files/document.pdf"),
    Some({ "_": "document.pdf" }),
  )
  assert_eq(route.match_path("/files/docs/readme.txt"), None)
}

///|
test "compiled route: multi-level wildcard" {
  let route = @crescent.CompiledRoute::compile("/static/**")
  assert_eq(
    route.match_path("/static/css/main.css"),
    Some({ "_": "css/main.css" }),
  )
  assert_eq(
    route.match_path("/static/images/icons/user.png"),
    Some({ "_": "images/icons/user.png" }),
  )
}

///|
test "compiled route: mixed parameter and wildcard" {
  let route = @crescent.CompiledRoute::compile("/users/:id/files/*")
  assert_eq(
    route.match_path("/users/123/files/avatar.jpg"),
    Some({ "id": "123", "_": "avatar.jpg" }),
  )
}

///|
test "compiled route: segments are pre-parsed" {
  let route = @crescent.CompiledRoute::compile("/api/:version/users/:id")
  assert_eq(route.segments.length(), 5) // "", "api", ":version", "users", ":id"
  assert_true(route.segments[0] is @crescent.Static(_))
  assert_true(route.segments[2] is @crescent.Param(_))
  assert_true(route.segments[4] is @crescent.Param(_))
}
