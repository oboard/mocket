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
    return if template_part == "**" { Some(params) } else { None }
  }

  // 都有内容，继续匹配
  let template_part = template_parts[template_idx]
  let path_part = path_parts[path_idx]

  // 使用正则匹配参数模式
  if template_part.view() =~ (re"^:", after=param_name) {
    // 命名参数：:param_name
    params.set(param_name.to_owned(), path_part)
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
priv struct DynamicRouteHandlerEntry {
  order : Int
  handler : HttpHandler
}

///|
priv enum DynamicRouteTrieEdge {
  Static(String, DynamicRouteTrieNode)
  Param(String, DynamicRouteTrieNode)
  Wildcard(DynamicRouteTrieNode)
  DeepWildcard(DynamicRouteHandlerEntry)
}

///|
priv struct DynamicRouteTrieNode {
  mut handler_entry : DynamicRouteHandlerEntry?
  children : Map[String, DynamicRouteTrieNode]
  edges : Array[DynamicRouteTrieEdge]
}

///|
priv struct DynamicRouteMatch {
  order : Int
  handler : HttpHandler
  params : Map[String, StringView]
}

///|
fn new_dynamic_route_trie_node() -> DynamicRouteTrieNode {
  { handler_entry: None, children: {}, edges: [] }
}

///|
fn copy_route_params(
  params : Map[String, StringView],
) -> Map[String, StringView] {
  let copied : Map[String, StringView] = {}
  params.iter().each(item => copied.set(item.0, item.1))
  copied
}

///|
fn better_dynamic_route_match(
  current : DynamicRouteMatch?,
  candidate : DynamicRouteMatch?,
) -> DynamicRouteMatch? {
  match (current, candidate) {
    (None, None) => None
    (Some(found), None) => Some(found)
    (None, Some(found)) => Some(found)
    (Some(found), Some(next)) =>
      if next.order < found.order {
        Some(next)
      } else {
        Some(found)
      }
  }
}

///|
fn dynamic_route_remaining_path(
  path_parts : Array[StringView],
  path_idx : Int,
) -> String {
  let remaining_path = []
  let mut i = path_idx
  while i < path_parts.length() {
    remaining_path.push(path_parts[i])
    i = i + 1
  }
  remaining_path.join("/")
}

///|
fn DynamicRouteTrieNode::static_child(
  self : DynamicRouteTrieNode,
  segment : String,
) -> DynamicRouteTrieNode? {
  self.children.get(segment)
}

///|
fn DynamicRouteTrieNode::param_child(
  self : DynamicRouteTrieNode,
  name : String,
) -> DynamicRouteTrieNode? {
  let mut found : DynamicRouteTrieNode? = None
  let mut searching = true
  let mut i = 0
  while i < self.edges.length() && searching {
    match self.edges[i] {
      Param(param_name, child) =>
        if param_name == name {
          found = Some(child)
          searching = false
        }
      _ => ignore(())
    }
    i = i + 1
  }
  found
}

///|
fn DynamicRouteTrieNode::wildcard_child(
  self : DynamicRouteTrieNode,
) -> DynamicRouteTrieNode? {
  let mut found : DynamicRouteTrieNode? = None
  let mut searching = true
  let mut i = 0
  while i < self.edges.length() && searching {
    match self.edges[i] {
      Wildcard(child) => {
        found = Some(child)
        searching = false
      }
      _ => ignore(())
    }
    i = i + 1
  }
  found
}

///|
fn DynamicRouteTrieNode::insert(
  self : DynamicRouteTrieNode,
  template : String,
  handler : HttpHandler,
  order : Int,
) -> Unit {
  let template_parts = template.split("/")
  let parts = template_parts.to_array()
  let mut node = self
  let mut i = 0
  while i < parts.length() {
    let part = parts[i]
    if part == "**" {
      node.edges.push(DeepWildcard({ order, handler }))
      return
    } else if part == "*" {
      node = match node.wildcard_child() {
        Some(child) => child
        None => {
          let child = new_dynamic_route_trie_node()
          node.edges.push(Wildcard(child))
          child
        }
      }
    } else if part.view() =~ (re"^:", after=param_name) {
      let param_name = param_name.to_owned()
      node = match node.param_child(param_name) {
        Some(child) => child
        None => {
          let child = new_dynamic_route_trie_node()
          node.edges.push(Param(param_name, child))
          child
        }
      }
    } else {
      let segment = part.to_owned()
      node = match node.static_child(segment) {
        Some(child) => child
        None => {
          let child = new_dynamic_route_trie_node()
          node.children.set(segment, child)
          node.edges.push(Static(segment, child))
          child
        }
      }
    }
    i = i + 1
  }
  match node.handler_entry {
    None => node.handler_entry = Some({ order, handler })
    Some(_) => ignore(())
  }
}

///|
fn DynamicRouteTrieNode::find(
  self : DynamicRouteTrieNode,
  path_parts : Array[StringView],
  path_idx : Int,
  params : Map[String, StringView],
) -> DynamicRouteMatch? {
  let mut found = if path_idx >= path_parts.length() {
    match self.handler_entry {
      Some(entry) =>
        Some({ order: entry.order, handler: entry.handler, params })
      None => None
    }
  } else {
    None
  }
  let mut i = 0
  while i < self.edges.length() {
    let edge = self.edges[i]
    let candidate = match edge {
      Static(segment, child) =>
        if path_idx < path_parts.length() && path_parts[path_idx] == segment {
          child.find(path_parts, path_idx + 1, copy_route_params(params))
        } else {
          None
        }
      Param(param_name, child) =>
        if path_idx < path_parts.length() {
          let next_params = copy_route_params(params)
          next_params.set(param_name, path_parts[path_idx])
          child.find(path_parts, path_idx + 1, next_params)
        } else {
          None
        }
      Wildcard(child) =>
        if path_idx < path_parts.length() {
          let next_params = copy_route_params(params)
          next_params.set("_", path_parts[path_idx])
          child.find(path_parts, path_idx + 1, next_params)
        } else {
          None
        }
      DeepWildcard(entry) => {
        let next_params = copy_route_params(params)
        if path_idx < path_parts.length() {
          next_params.set(
            "_",
            dynamic_route_remaining_path(path_parts, path_idx),
          )
        }
        Some({ order: entry.order, handler: entry.handler, params: next_params })
      }
    }
    found = better_dynamic_route_match(found, candidate)
    i = i + 1
  }
  found
}

///|
fn Mocket::insert_dynamic_route(
  self : Mocket,
  event : String,
  path : String,
  handler : HttpHandler,
) -> Unit {
  let order = match self.dynamic_routes.get(event) {
    Some(routes) => {
      let order = routes.length()
      routes.push((path, handler))
      order
    }
    None => {
      self.dynamic_routes.set(event, [(path, handler)])
      0
    }
  }
  let trie = match self.dynamic_route_tries.get(event) {
    Some(existing) => existing
    None => {
      let trie = new_dynamic_route_trie_node()
      self.dynamic_route_tries.set(event, trie)
      trie
    }
  }
  trie.insert(path, handler, order)
}

///|
fn DynamicRouteTrieNode::find_path(
  self : DynamicRouteTrieNode,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  let path_parts = path.split("/").collect()
  match self.find(path_parts, 0, {}) {
    Some(found) => Some((found.handler, found.params))
    None => None
  }
}

///|
// 查找匹配的路由和参数
fn Mocket::find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  // 优化：首先尝试静态路由缓存
  match self.static_routes.get(http_method) {
    Some(http_methodroutes) =>
      match http_methodroutes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ignore(())
      }
    None => ignore(())
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

  // 然后尝试动态路由 trie
  if self.dynamic_route_tries.get(http_method) is Some(trie) {
    if trie.find_path(path) is Some(found) {
      return Some(found)
    }
  }

  // 最后检查通配符方法的动态路由 trie
  if self.dynamic_route_tries.get("*") is Some(trie) {
    if trie.find_path(path) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
// 路径匹配测试用例 - 全面覆盖各种场景

test "静态路径匹配" {
  @test.assert_eq(match_path("/api/users", "/api/users"), Some({}))
  @test.assert_eq(match_path("/api/users", "/api/posts"), None)
  @test.assert_eq(match_path("/", "/"), Some({}))
}

///|
test "命名参数匹配" {
  @test.assert_eq(match_path("/users/:id", "/users/123"), Some({ "id": "123" }))
  @test.assert_eq(
    match_path("/users/:userId/posts/:postId", "/users/456/posts/789"),
    Some({ "userId": "456", "postId": "789" }),
  )
  @test.assert_eq(match_path("/users/:id", "/users/123/extra"), None)
}

///|
test "单级通配符匹配" {
  @test.assert_eq(
    match_path("/files/*", "/files/document.pdf"),
    Some({ "_": "document.pdf" }),
  )
  @test.assert_eq(
    match_path("/api/*/status", "/api/v1/status"),
    Some({ "_": "v1" }),
  )
  @test.assert_eq(match_path("/files/*", "/files/docs/readme.txt"), None)
}

///|
test "多级通配符匹配" {
  @test.assert_eq(
    match_path("/static/**", "/static/css/main.css"),
    Some({ "_": "css/main.css" }),
  )
  @test.assert_eq(
    match_path("/assets/**", "/assets/images/icons/user.png"),
    Some({ "_": "images/icons/user.png" }),
  )
  @test.assert_eq(
    match_path("/docs/**", "/docs/readme.md"),
    Some({ "_": "readme.md" }),
  )
  @test.assert_eq(match_path("/api/v1/**", "/api/v1/"), Some({ "_": "" }))
}

///|
test "复杂混合模式" {
  // 参数 + 通配符
  let result = match_path("/users/:id/files/*", "/users/123/files/avatar.jpg")
  @test.assert_eq(result, Some({ "id": "123", "_": "avatar.jpg" }))

  // 参数 + 多级通配符
  let result2 = match_path(
    "/projects/:projectId/**", "/projects/abc/src/main.mbt",
  )
  @test.assert_eq(result2, Some({ "projectId": "abc", "_": "src/main.mbt" }))

  // 多个参数 + 静态段
  let result3 = match_path(
    "/api/:version/users/:id/profile", "/api/v2/users/456/profile",
  )
  @test.assert_eq(result3, Some({ "version": "v2", "id": "456" }))
}

///|
test "边界情况" {
  // 空路径段
  let result = match_path("/api//users", "/api//users")
  @test.assert_eq(result, Some({}))

  // 路径末尾斜杠
  let result2 = match_path("/api/users/", "/api/users/")
  @test.assert_eq(result2, Some({}))

  // 参数名为空
  let result3 = match_path("/users/:", "/users/123")
  @test.assert_eq(result3, Some({ "": "123" }))

  // 模板比路径短
  let result4 = match_path("/api", "/api/users")
  @test.assert_eq(result4, None)

  // 路径比模板短（非通配符）
  let result5 = match_path("/api/users", "/api")
  @test.assert_eq(result5, None)
}

///|
test "性能对比场景" {
  // 静态路径应该快速返回
  let result = match_path("/health", "/health")
  @test.assert_eq(result, Some({}))

  // 复杂模式也应该高效
  let result2 = match_path(
    "/api/:v/users/:id/posts/:postId/comments/*", "/api/v1/users/123/posts/456/comments/789",
  )
  @test.assert_eq(
    result2,
    Some({ "v": "v1", "id": "123", "postId": "456", "_": "789" }),
  )
}

///|
test "lexmatch 特殊字符处理" {
  // 包含特殊字符的参数
  let result = match_path("/search/:query", "/search/hello%20world")
  @test.assert_eq(result, Some({ "query": "hello%20world" }))

  // 包含点号的文件名
  let result2 = match_path("/files/*", "/files/config.json")
  @test.assert_eq(result2, Some({ "_": "config.json" }))
}

///|
test "动态路由 trie 匹配命名参数" {
  let app = new()
  app.get("/name/:id/x", _ => "ok")
  match app.find_route("GET", "/name/42/x") {
    Some((_, params)) => @test.assert_eq(params, { "id": "42" })
    None => fail("Expected dynamic route match")
  }
}

///|
test "动态路由 trie 保留注册顺序" {
  let app = new()
  app.get("/users/:id/profile", _ => "first")
  app.get("/users/me/:tab", _ => "second")
  match app.find_route("GET", "/users/me/profile") {
    Some((_, params)) => @test.assert_eq(params, { "id": "me" })
    None => fail("Expected first registered dynamic route")
  }
}

///|
test "动态路由 trie 合并分组路由" {
  let app = new()
  app.group("/api", group => group.get("/users/:id", _ => "ok"))
  match app.find_route("GET", "/api/users/7") {
    Some((_, params)) => @test.assert_eq(params, { "id": "7" })
    None => fail("Expected grouped dynamic route match")
  }
}
