///|
// 匹配路径并提取参数
fn match_path(template : String, path : String) -> Map[String, String]? {
  // 如果模板中没有参数和通配符，直接比较
  if template.find(":").unwrap_or(-1) == -1 &&
    template.find("*").unwrap_or(-1) == -1 {
    if template == path {
      return Some({})
    } else {
      return None
    }
  }

  // 构建正则表达式
  let regex_str = template_to_regex(template)
  guard (try? @regexp.compile(regex_str)) is Ok(regexp) else { return None }
  let match_result = regexp.matches(path)
  if not(match_result.success()) {
    return None
  }

  // 提取参数名和通配符位置
  let template_parts = template.split("/").to_array()
  let param_names = []
  let mut i = 0
  while i < template_parts.length() {
    let part = template_parts[i].to_string()
    if part.find(":").unwrap_or(-1) == 0 {
      param_names.push(part.view(start_offset=1).to_string())
    } else if part == "*" {
      param_names.push("*")
    } else if part == "**" {
      param_names.push("**")
    }
    i = i + 1
  }

  // 构建参数映射
  let params = {}
  let captures = match_result.captures()
  let mut param_index = 0
  let mut capture_index = 1 // 跳过第一个完整匹配
  while param_index < param_names.length() && capture_index < captures.length() {
    let param_name = param_names[param_index]
    let param_value = captures[capture_index]
    if param_name == "*" {
      // 单星号参数，匹配单级路径
      params.set("_", param_value)
    } else if param_name == "**" {
      // 双星号参数，匹配多级路径
      params.set("_", param_value)
    } else {
      // 命名参数
      params.set(param_name, param_value)
    }
    param_index = param_index + 1
    capture_index = capture_index + 1
  }
  Some(params)
}

///|
// 查找匹配的路由和参数
fn find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (async (HttpEvent) -> HttpBody noraise, Map[String, String])? {
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
