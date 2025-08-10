///|
pub(all) struct Mocket {
  base_path : String
  mappings : Map[(String, String), async (HttpEvent) -> Json noraise]
  middlewares : Array[(String, async (HttpEvent) -> Unit noraise)]
  // 添加静态路由缓存（精确匹配的路由）
  static_routes : Map[String, Map[String, async (HttpEvent) -> Json noraise]]
  // 添加动态路由缓存（包含参数的路由）
  dynamic_routes : Map[
    String,
    Array[(String, async (HttpEvent) -> Json noraise)],
  ]
}

///|
pub typealias Mocket as T

///|
pub fn new(base_path~ : String = "") -> Mocket {
  {
    base_path,
    mappings: {},
    middlewares: [],
    static_routes: {},
    dynamic_routes: {},
  }
}

///|
pub struct HttpRequest {
  reqMethod : String
  url : String
  headers : Map[String, String]
  mut body : String
}

///|
pub(all) struct HttpResponse {
  mut statusCode : Int
  headers : Map[String, String]
  // body : String
}

///|
// 将路径模板转换为正则表达式
fn template_to_regex(template : String) -> String {
  // 优化：避免重复的字符串操作
  if template.find(":").unwrap_or(-1) == -1 &&
    template.find("*").unwrap_or(-1) == -1 {
    return "^" + template + "$"
  }
  let parts = template.split("/")
  let result_parts = []
  for part in parts {
    let part_str = part.to_string()
    if part_str.length() > 0 &&
      part_str.view(start_offset=0, end_offset=1) == ":" {
      result_parts.push("([^/]+)")
    } else if part_str == "*" {
      result_parts.push("([^/]+)")
    } else if part_str == "**" {
      result_parts.push("(.*)")
    } else {
      result_parts.push(part_str)
    }
  }
  "^" + result_parts.join("/") + "$"
}

///|
pub fn on(
  self : Mocket,
  event : String,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  let path = self.base_path + path
  self.mappings.set((event, path), handler)

  // 优化：根据路径类型分别缓存
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    // 静态路径，直接缓存
    match self.static_routes.get(event) {
      Some(method_routes) => method_routes.set(path, handler)
      None => {
        let new_routes = {}
        new_routes.set(path, handler)
        self.static_routes.set(event, new_routes)
      }
    }
  } else {
    // 动态路径，加入动态路由列表
    match self.dynamic_routes.get(event) {
      Some(routes) => routes.push((path, handler))
      None => {
        let new_routes = [(path, handler)]
        self.dynamic_routes.set(event, new_routes)
      }
    }
  }
}

///|
pub fn get(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn post(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn patch(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn connect(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn put(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn delete(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn head(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn options(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn trace(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn all(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
  self.on("*", path, handler)
}

///|
// 创建路由组
pub fn group(
  self : Mocket,
  base_path : String,
  configure : (Mocket) -> Unit,
) -> Unit {
  let group = new(base_path=self.base_path + base_path)
  configure(group)
  // 合并路由
  group.mappings.iter().each(i => self.mappings.set(i.0, i.1))
  group.static_routes.iter().each(i => self.static_routes.set(i.0, i.1))
  group.dynamic_routes
  .iter()
  .each(i => {
    let event = i.0
    let routes = i.1
    if self.dynamic_routes.get(event) is Some(existing_routes) {
      existing_routes.append(routes)
    } else {
      self.dynamic_routes.set(event, routes)
    }
  })
  // 合并中间件
  group.middlewares.iter().each(self.middlewares.push(_))
}
