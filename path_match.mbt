///|
// 匹配路径并提取参数 - 重写版本，消除复杂性
fn match_path(template : String, path : String) -> Map[String, StringView]? {
  // 静态路径直接比较 - 好品味：消除特殊情况
  if !template.contains(":") && !template.contains("*") {
    return if template == path { Some({}) } else { None }
  }

  // 使用递归进行路径匹配和参数提取
  let template_parts = template.split("/")
  let path_parts = path.split("/").collect()
  match_path_segments(template_parts.to_array(), path_parts, 0, 0, {})
}

///|
// 递归匹配路径段 - 简洁的核心逻辑
fn match_path_segments(
  template_parts : Array[StringView],
  path_parts : Array[StringView],
  template_idx : Int,
  path_idx : Int,
  params : Map[String, StringView],
) -> Map[String, StringView]? {
  // 都结束了，匹配成功
  if template_idx >= template_parts.length() && path_idx >= path_parts.length() {
    return Some(params)
  }

  // 模板结束但路径还有，失败
  if template_idx >= template_parts.length() {
    return None
  }

  // 路径结束但模板还有
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

  // 都有内容，继续匹配
  let template_part = template_parts[template_idx]
  let path_part = path_parts[path_idx]

  // 使用 lexmatch? 匹配参数模式
  if template_part.view() lexmatch? (":", param_name) {
    // 命名参数：:param_name
    params.set(param_name.to_string(), path_part)
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else if template_part == "*" {
    // 单级通配符
    params.set("_", path_part)
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else if template_part == "**" {
    // 多级通配符 - 可以匹配零个或多个路径段
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
    // 静态段匹配
    match_path_segments(
      template_parts,
      path_parts,
      template_idx + 1,
      path_idx + 1,
      params,
    )
  } else {
    // 不匹配
    None
  }
}

///|
fn Mocket::find_route_for_method(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  match self.static_routes.get(http_method) {
    Some(http_methodroutes) =>
      match http_methodroutes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ignore(())
      }
    None => ignore(())
  }

  if self.dynamic_routes.get(http_method) is Some(routes) {
    let mut i = 0
    while i < routes.length() {
      let route_item = routes[i]
      let route_path = route_item.0
      let handler = route_item.1
      if match_path(route_path, path) is Some(params) {
        return Some((handler, params))
      }
      i = i + 1
    }
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
// 查找匹配的路由和参数
fn Mocket::find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  match self.find_route_for_method(http_method, path) {
    Some(route) => return Some(route)
    None => ()
  }
  match self.static_routes.get("*") {
    Some(http_methodroutes) =>
      match http_methodroutes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ()
      }
    None => ()
  }

  if self.dynamic_routes.get("*") is Some(routes) {
    let mut i = 0
    while i < routes.length() {
      let route_item = routes[i]
      let route_path = route_item.0
      let handler = route_item.1
      if match_path(route_path, path) is Some(params) {
        return Some((handler, params))
      }
      i = i + 1
    }
  }
  None
}

///|
fn Mocket::find_ws_route(self : Mocket, path : String) -> WebSocketHandler? {
  match self.ws_static_routes.get(path) {
    Some(handler) => return Some(handler)
    None => ()
  }
  let mut i = 0
  while i < self.ws_dynamic_routes.length() {
    let route_item = self.ws_dynamic_routes[i]
    let route_path = route_item.0
    let handler = route_item.1
    if match_path(route_path, path) is Some(_) {
      return Some(handler)
    }
    i = i + 1
  }
  None
}

///|
// 路径匹配测试用例 - 全面覆盖各种场景

test "静态路径匹配" {
  assert_eq(match_path("/api/users", "/api/users"), Some({}))
  assert_eq(match_path("/api/users", "/api/posts"), None)
  assert_eq(match_path("/", "/"), Some({}))
}

///|
test "命名参数匹配" {
  assert_eq(match_path("/users/:id", "/users/123"), Some({ "id": "123" }))
  assert_eq(
    match_path("/users/:userId/posts/:postId", "/users/456/posts/789"),
    Some({ "userId": "456", "postId": "789" }),
  )
  assert_eq(match_path("/users/:id", "/users/123/extra"), None)
}

///|
test "单级通配符匹配" {
  assert_eq(
    match_path("/files/*", "/files/document.pdf"),
    Some({ "_": "document.pdf" }),
  )
  assert_eq(match_path("/api/*/status", "/api/v1/status"), Some({ "_": "v1" }))
  assert_eq(match_path("/files/*", "/files/docs/readme.txt"), None)
}

///|
test "多级通配符匹配" {
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
test "复杂混合模式" {
  // 参数 + 通配符
  let result = match_path("/users/:id/files/*", "/users/123/files/avatar.jpg")
  assert_eq(result, Some({ "id": "123", "_": "avatar.jpg" }))

  // 参数 + 多级通配符
  let result2 = match_path(
    "/projects/:projectId/**", "/projects/abc/src/main.mbt",
  )
  assert_eq(result2, Some({ "projectId": "abc", "_": "src/main.mbt" }))

  // 多个参数 + 静态段
  let result3 = match_path(
    "/api/:version/users/:id/profile", "/api/v2/users/456/profile",
  )
  assert_eq(result3, Some({ "version": "v2", "id": "456" }))
}

///|
test "边界情况" {
  // 空路径段
  let result = match_path("/api//users", "/api//users")
  assert_eq(result, Some({}))

  // 路径末尾斜杠
  let result2 = match_path("/api/users/", "/api/users/")
  assert_eq(result2, Some({}))

  // 参数名为空
  let result3 = match_path("/users/:", "/users/123")
  assert_eq(result3, Some({ "": "123" }))

  // 模板比路径短
  let result4 = match_path("/api", "/api/users")
  assert_eq(result4, None)

  // 路径比模板短（非通配符）
  let result5 = match_path("/api/users", "/api")
  assert_eq(result5, None)
}

///|
test "性能对比场景" {
  // 静态路径应该快速返回
  let result = match_path("/health", "/health")
  assert_eq(result, Some({}))

  // 复杂模式也应该高效
  let result2 = match_path(
    "/api/:v/users/:id/posts/:postId/comments/*", "/api/v1/users/123/posts/456/comments/789",
  )
  assert_eq(
    result2,
    Some({ "v": "v1", "id": "123", "postId": "456", "_": "789" }),
  )
}

///|
test "lexmatch 特殊字符处理" {
  // 包含特殊字符的参数
  let result = match_path("/search/:query", "/search/hello%20world")
  assert_eq(result, Some({ "query": "hello%20world" }))

  // 包含点号的文件名
  let result2 = match_path("/files/*", "/files/config.json")
  assert_eq(result2, Some({ "_": "config.json" }))
}
