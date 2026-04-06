///|
// Match path and extract parameters
fn match_path(template : String, path : String) -> Map[String, StringView]? {
  // Static paths: direct comparison
  if !template.contains(":") && !template.contains("*") {
    return if template == path { Some({}) } else { None }
  }

  // Use recursion for path matching and parameter extraction
  let template_parts = template.split("/")
  let path_parts = path.split("/").collect()
  match_path_segments(template_parts.to_array(), path_parts, 0, 0, {})
}

///|
// Recursively match path segments
fn match_path_segments(
  template_parts : Array[StringView],
  path_parts : Array[StringView],
  template_idx : Int,
  path_idx : Int,
  params : Map[String, StringView],
) -> Map[String, StringView]? {
  // Both exhausted: match succeeded
  if template_idx >= template_parts.length() && path_idx >= path_parts.length() {
    return Some(params)
  }

  // Template exhausted but path remains: no match
  if template_idx >= template_parts.length() {
    return None
  }

  // Path exhausted but template remains
  if path_idx >= path_parts.length() {
    let template_part = template_parts[template_idx]
    return if template_part == "**" {
      let trial_params : Map[String, StringView] = {}
      params.each((key, value) => trial_params.set(key, value))
      trial_params.set("_", "")
      match_path_segments(
        template_parts,
        path_parts,
        template_idx + 1,
        path_idx,
        trial_params,
      )
    } else {
      None
    }
  }

  // Both have content: continue matching
  let template_part = template_parts[template_idx]
  let path_part = path_parts[path_idx]

  // Match parameter patterns using lexmatch
  if template_part.view() lexmatch? (":", param_name) {
    // Named parameter: :param_name
    params.set(param_name.to_string(), path_part)
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else if template_part == "*" {
    // Single-level wildcard
    params.set("_", path_part)
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else if template_part == "**" {
    // Multi-level wildcard: matches zero or more path segments
    let mut end_idx = path_idx
    while end_idx <= path_parts.length() {
      let matched_segments : Array[StringView] = []
      let mut i = path_idx
      while i < end_idx {
        matched_segments.push(path_parts[i])
        i = i + 1
      }
      let trial_params : Map[String, StringView] = {}
      params.each((key, value) => trial_params.set(key, value))
      trial_params.set("_", matched_segments.join("/"))
      match
        match_path_segments(
          template_parts,
          path_parts,
          template_idx + 1,
          end_idx,
          trial_params,
        ) {
        Some(result) => return Some(result)
        None => ()
      }
      end_idx = end_idx + 1
    }
    None
  } else if template_part == path_part {
    // Static segment match
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else {
    // No match
    None
  }
}

///|
fn Mocket::find_route_for_method(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  if self.static_routes.get(http_method) is Some(method_routes) {
    if method_routes.get(path) is Some(handler) {
      return Some((handler, {}))
    }
  }
  match self.dynamic_routes.search(http_method, path) {
    Some((handler, params)) => return Some((handler, params))
    None => ()
  }
  None
}

///|
fn Mocket::has_route_for_method(
  self : Mocket,
  http_method : String,
  path : String,
) -> Bool {
  self.find_route_for_method(http_method, path) is Some(_)
}

///|
fn Mocket::allowed_methods(
  self : Mocket,
  path : String,
  include_implicit_options : Bool,
) -> Array[String] {
  let allowed : Array[String] = []
  let supports_get = self.has_route_for_method("GET", path)
  let supports_head = self.has_route_for_method("HEAD", path)
  if supports_get {
    allowed.push("GET")
  }
  if supports_head || supports_get {
    allowed.push("HEAD")
  }
  for http_method in ["POST", "PUT", "PATCH", "DELETE"] {
    if self.has_route_for_method(http_method, path) {
      allowed.push(http_method)
    }
  }
  let supports_options = self.has_route_for_method("OPTIONS", path)
  if supports_options || (include_implicit_options && !allowed.is_empty()) {
    allowed.push("OPTIONS")
  }
  for http_method in ["TRACE", "CONNECT"] {
    if self.has_route_for_method(http_method, path) {
      allowed.push(http_method)
    }
  }
  allowed
}

///|
// Find matching route and parameters
fn Mocket::find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  if self.find_route_for_method(http_method, path) is Some(route) {
    return Some(route)
  }
  if self.static_routes.get("*") is Some(wildcard_routes) {
    if wildcard_routes.get(path) is Some(handler) {
      return Some((handler, {}))
    }
  }
  match self.dynamic_routes.search("*", path) {
    Some((handler, params)) => return Some((handler, params))
    None => ()
  }
  None
}

///|
fn Mocket::find_ws_route(self : Mocket, path : String) -> WebSocketHandler? {
  if self.ws_static_routes.get(path) is Some(handler) {
    return Some(handler)
  }
  for route in self.ws_dynamic_routes {
    let (compiled, handler) = route
    if compiled.match_path(path) is Some(_) {
      return Some(handler)
    }
  }
  None
}

///|
// Path matching tests

test "static path matching" {
  assert_eq(match_path("/api/users", "/api/users"), Some({}))
  assert_eq(match_path("/api/users", "/api/posts"), None)
  assert_eq(match_path("/", "/"), Some({}))
}

///|
test "named parameter matching" {
  assert_eq(match_path("/users/:id", "/users/123"), Some({ "id": "123" }))
  assert_eq(
    match_path("/users/:userId/posts/:postId", "/users/456/posts/789"),
    Some({ "userId": "456", "postId": "789" }),
  )
  assert_eq(match_path("/users/:id", "/users/123/extra"), None)
}

///|
test "single-level wildcard matching" {
  assert_eq(
    match_path("/files/*", "/files/document.pdf"),
    Some({ "_": "document.pdf" }),
  )
  assert_eq(match_path("/api/*/status", "/api/v1/status"), Some({ "_": "v1" }))
  assert_eq(match_path("/files/*", "/files/docs/readme.txt"), None)
}

///|
test "multi-level wildcard matching" {
  assert_eq(
    match_path("/static/**", "/static/css/main.css"),
    Some({ "_": "css/main.css" }),
  )
  assert_eq(
    match_path("/assets/**", "/assets/images/icons/user.png"),
    Some({ "_": "images/icons/user.png" }),
  )
  assert_eq(
    match_path("/docs/**", "/docs/readme.md"),
    Some({ "_": "readme.md" }),
  )
  assert_eq(match_path("/api/v1/**", "/api/v1/"), Some({ "_": "" }))
  assert_eq(
    match_path("/files/**/meta", "/files/a/b/meta"),
    Some({ "_": "a/b" }),
  )
  assert_eq(match_path("/files/**/meta", "/files/a/b/raw"), None)
  assert_eq(match_path("/files/**/meta", "/files"), None)
}

///|
test "complex mixed patterns" {
  // Parameter + wildcard
  let result = match_path("/users/:id/files/*", "/users/123/files/avatar.jpg")
  assert_eq(result, Some({ "id": "123", "_": "avatar.jpg" }))

  // Parameter + multi-level wildcard
  let result2 = match_path(
    "/projects/:projectId/**", "/projects/abc/src/main.mbt",
  )
  assert_eq(result2, Some({ "projectId": "abc", "_": "src/main.mbt" }))

  // Multiple parameters + static segments
  let result3 = match_path(
    "/api/:version/users/:id/profile", "/api/v2/users/456/profile",
  )
  assert_eq(result3, Some({ "version": "v2", "id": "456" }))
}

///|
test "edge cases" {
  // Empty path segment
  let result = match_path("/api//users", "/api//users")
  assert_eq(result, Some({}))

  // Trailing slash
  let result2 = match_path("/api/users/", "/api/users/")
  assert_eq(result2, Some({}))

  // Empty parameter name
  let result3 = match_path("/users/:", "/users/123")
  assert_eq(result3, Some({ "": "123" }))

  // Template shorter than path
  let result4 = match_path("/api", "/api/users")
  assert_eq(result4, None)

  // Path shorter than template (non-wildcard)
  let result5 = match_path("/api/users", "/api")
  assert_eq(result5, None)
}

///|
test "performance scenarios" {
  // Static paths should return quickly
  let result = match_path("/health", "/health")
  assert_eq(result, Some({}))

  // Complex patterns should also be efficient
  let result2 = match_path(
    "/api/:v/users/:id/posts/:postId/comments/*", "/api/v1/users/123/posts/456/comments/789",
  )
  assert_eq(
    result2,
    Some({ "v": "v1", "id": "123", "postId": "456", "_": "789" }),
  )
}

///|
test "special character handling" {
  // Parameters with special characters
  let result = match_path("/search/:query", "/search/hello%20world")
  assert_eq(result, Some({ "query": "hello%20world" }))

  // Filename with dots
  let result2 = match_path("/files/*", "/files/config.json")
  assert_eq(result2, Some({ "_": "config.json" }))
}
