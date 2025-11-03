///|
// 匹配路径并提取参数 - 重写版本，消除复杂性
fn match_path(template : String, path : String) -> Map[String, StringView]? {
  // 静态路径直接比较 - 好品味：消除特殊情况
  if not(template.contains(":")) && not(template.contains("*")) {
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
    return if template_part == "**" { Some(params) } else { None }
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
    // 多级通配符 - 贪婪匹配剩余所有
    let remaining_path = []
    let mut i = path_idx
    while i < path_parts.length() {
      remaining_path.push(path_parts[i])
      i = i + 1
    }
    params.set("_", remaining_path.join("/"))
    Some(params)
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
// 查找匹配的路由和参数
fn Mocket::find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  self.logger.route_lookup(http_method, path)
  // 优化：首先尝试静态路由缓存
  match self.static_routes.get(http_method) {
    Some(http_methodroutes) => {
      let routes = []
      http_methodroutes.iter().each(fn(item) { routes.push(item.0) })
      self.logger.routes_available(routes)
      match http_methodroutes.get(path) {
        Some(handler) => {
          self.logger.route_found(http_method, path)
          return Some((handler, {}))
        }
        None => {
          self.logger.route_not_found(path)
          ignore(())
        }
      }
    }
    None => {
      self.logger.debug(fn() { "No method routes for \{http_method}" })
      ignore(())
    }
  }

  // 检查通配符方法的静态路由
  match self.static_routes.get("*") {
    Some(http_methodroutes) =>
      match http_methodroutes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ignore(())
      }
    None => ignore(())
  }

  // 然后尝试动态路由
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

  // 最后检查通配符方法的动态路由
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

  // 参数名为空（不应该匹配）
  let result3 = match_path("/users/:", "/users/123")
  assert_eq(result3, None)

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
