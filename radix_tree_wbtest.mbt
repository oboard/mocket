///|
test "radix tree: static routes" {
  let router : RadixRouter[String] = RadixRouter::new()
  router.insert("GET", CompiledRoute::compile("/api/users"), "list_users")
  router.insert("GET", CompiledRoute::compile("/api/posts"), "list_posts")
  match router.search("GET", "/api/users") {
    Some((handler, _)) => assert_eq(handler, "list_users")
    None => fail("Expected to find route")
  }
  match router.search("GET", "/api/posts") {
    Some((handler, _)) => assert_eq(handler, "list_posts")
    None => fail("Expected to find route")
  }
  assert_true(router.search("GET", "/api/missing") is None)
  assert_true(router.search("POST", "/api/users") is None)
}

///|
test "radix tree: param routes" {
  let router : RadixRouter[String] = RadixRouter::new()
  router.insert("GET", CompiledRoute::compile("/users/:id"), "get_user")
  router.insert(
    "GET",
    CompiledRoute::compile("/users/:id/posts/:postId"),
    "get_user_post",
  )
  match router.search("GET", "/users/42") {
    Some((handler, params)) => {
      assert_eq(handler, "get_user")
      assert_eq(params.get("id").map(StringView::to_string), Some("42"))
    }
    None => fail("Expected to find route")
  }
  match router.search("GET", "/users/42/posts/99") {
    Some((handler, params)) => {
      assert_eq(handler, "get_user_post")
      assert_eq(params.get("id").map(StringView::to_string), Some("42"))
      assert_eq(params.get("postId").map(StringView::to_string), Some("99"))
    }
    None => fail("Expected to find route")
  }
}

///|
test "radix tree: wildcard routes" {
  let router : RadixRouter[String] = RadixRouter::new()
  router.insert("GET", CompiledRoute::compile("/files/*"), "get_file")
  match router.search("GET", "/files/readme.txt") {
    Some((handler, params)) => {
      assert_eq(handler, "get_file")
      assert_eq(params.get("_").map(StringView::to_string), Some("readme.txt"))
    }
    None => fail("Expected to find route")
  }
  assert_true(router.search("GET", "/files/a/b") is None)
}

///|
test "radix tree: globstar routes" {
  let router : RadixRouter[String] = RadixRouter::new()
  router.insert("GET", CompiledRoute::compile("/static/**"), "serve_static")
  match router.search("GET", "/static/css/main.css") {
    Some((handler, params)) => {
      assert_eq(handler, "serve_static")
      assert_eq(
        params.get("_").map(StringView::to_string),
        Some("css/main.css"),
      )
    }
    None => fail("Expected to find route")
  }
}

///|
test "radix tree: mixed static and param on same level" {
  let router : RadixRouter[String] = RadixRouter::new()
  router.insert("GET", CompiledRoute::compile("/users/me"), "current_user")
  router.insert("GET", CompiledRoute::compile("/users/:id"), "get_user")
  // Static should take priority
  match router.search("GET", "/users/me") {
    Some((handler, _)) => assert_eq(handler, "current_user")
    None => fail("Expected to find route")
  }
  // Param matches other values
  match router.search("GET", "/users/42") {
    Some((handler, _)) => assert_eq(handler, "get_user")
    None => fail("Expected to find route")
  }
}

///|
test "radix tree: merge routers" {
  let router1 : RadixRouter[String] = RadixRouter::new()
  router1.insert("GET", CompiledRoute::compile("/api/users/:id"), "get_user")
  let router2 : RadixRouter[String] = RadixRouter::new()
  router2.insert("POST", CompiledRoute::compile("/api/users"), "create_user")
  router1.merge(router2)
  assert_true(router1.search("GET", "/api/users/1") is Some(_))
  assert_true(router1.search("POST", "/api/users") is Some(_))
}
