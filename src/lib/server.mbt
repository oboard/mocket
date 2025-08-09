///|
pub suberror IOError derive(Show)

///|
pub suberror NetworkError derive(Show)

///|
pub suberror ExecError derive(Show)

///|
pub fn run(f : async () -> Unit noraise) -> Unit = "%async.run"

///| `suspend` 会中断当前协程的运行。
/// `suspend` 会接受一个回调函数，并让这个回调函数来操作中断的协程
pub async fn[T, E : Error] suspend(
  // `f` 是负责操作中断的协程的回调函数
  f : (
    // `f` 的第一个参数用于继续运行被中断的协程
    (T) -> Unit,
    // `f` 的第二个参数用于取消被中断的协程。
    // 取消会被表示为在中断处抛出错误
    (E) -> Unit,
  ) -> Unit,
) -> T raise E = "%async.suspend"

///|
pub(all) struct Mocket {
  mappings : Map[(String, String), async (HttpEvent) -> Json noraise]
  middlewares : Array[async (HttpEvent) -> Unit noraise]
  // 添加正则表达式缓存，类型暂时使用 Json 占位符
  regex_cache : Map[String, Json]
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
pub fn new() -> Mocket {
  {
    mappings: {},
    middlewares: [],
    regex_cache: {},
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
pub struct HttpEvent {
  req : HttpRequest
  res : HttpResponse
  mut params : Map[String, String]
}

///|
// 将路径模板转换为正则表达式
fn templateToRegex(template : String) -> String {
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
// 匹配路径并提取参数
fn matchPath(template : String, path : String) -> Map[String, String]? {
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
  let regex_str = templateToRegex(template)
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
pub fn on(
  self : Mocket,
  event : String,
  path : String,
  handler : async (HttpEvent) -> Json noraise,
) -> Unit {
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
// 注册全局中间件
pub fn use_middleware(
  self : Mocket,
  middleware : async (HttpEvent) -> Unit noraise,
) -> Unit {
  self.middlewares.push(middleware)
}

///|
// 执行中间件链
fn executeMiddlewares(
  middlewares : Array[async (HttpEvent) -> Unit noraise],
  event : HttpEvent,
) -> Unit {
  // 优化：使用迭代而不是递归，避免栈溢出
  let mut i = 0
  while i < middlewares.length() {
    let middleware = middlewares[i]
    run(fn() { middleware(event) })
    i = i + 1
  }
}

///|
// 查找匹配的路由和参数
fn findRoute(
  self : Mocket,
  reqMethod : String,
  path : String,
) -> (async (HttpEvent) -> Json noraise, Map[String, String])? {
  // 优化：首先尝试静态路由缓存
  match self.static_routes.get(reqMethod) {
    Some(method_routes) =>
      match method_routes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ignore(())
      }
    None => ignore(())
  }

  // 检查通配符方法的静态路由
  match self.static_routes.get("*") {
    Some(method_routes) =>
      match method_routes.get(path) {
        Some(handler) => return Some((handler, {}))
        None => ignore(())
      }
    None => ignore(())
  }

  // 然后尝试动态路由
  match self.dynamic_routes.get(reqMethod) {
    Some(routes) => {
      let mut i = 0
      while i < routes.length() {
        let route_item = routes[i]
        let route_path = route_item.0
        let handler = route_item.1
        match matchPath(route_path, path) {
          Some(params) => return Some((handler, params))
          None => ignore(())
        }
        i = i + 1
      }
    }
    None => ignore(())
  }

  // 最后检查通配符方法的动态路由
  match self.dynamic_routes.get("*") {
    Some(routes) => {
      let mut i = 0
      while i < routes.length() {
        let route_item = routes[i]
        let route_path = route_item.0
        let handler = route_item.1
        match matchPath(route_path, path) {
          Some(params) => return Some((handler, params))
          None => ignore(())
        }
        i = i + 1
      }
    }
    None => ignore(())
  }
  None
}

///|
pub fn serve(self : Mocket, port~ : Int) -> Unit {
  createServer(
    fn(req, res, _) {
      // 优化：简化 headers 转换逻辑
      let string_headers = {}
      guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
        res.writeHead(400, @js.Object::new().to_value())
        res.end("Invalid headers")
        return
      }

      // 批量转换 headers，减少单个处理的开销
      headers.each(fn(key, value) {
        match value {
          String(v) => string_headers.set(key, v)
          _ => ignore(()) // 忽略非字符串 header
        }
      })
      let event = {
        req: {
          reqMethod: req.reqMethod(),
          url: req.url(),
          body: "",
          headers: string_headers,
        },
        res: { statusCode: 200, headers: {} },
        params: {},
      }

      // 查找匹配的路由
      guard self.findRoute(req.reqMethod(), req.url())
        is Some((handler, params)) else {
        res.writeHead(404, @js.Object::new().to_value())
        res.end("Not Found")
        return
      }

      // 设置路径参数
      event.params = params
      run(fn() {
        // 如果是 post，先等待 data 事件
        if event.req.reqMethod == "POST" {
          let body = suspend(fn(res, _) {
            let buffer = @buffer.new()
            req.on("data", fn(data) { buffer.write_string(data.to_string()) })
            req.on("end", fn(_) { res(buffer.to_string()) })
          }) catch {
            err => abort(err)
          }
          event.req.body = body
        }

        // 执行中间件链
        executeMiddlewares(self.middlewares, event)
        let response = handler(event)
        let body = match response {
          { "__": String(contentType), "body": body, .. } => {
            event.res.headers.set("Content-Type", contentType)
            body
          }
          _ => {
            match response {
              Json::Object(_) =>
                event.res.headers.set(
                  "Content-Type", "application/json;charset=UTF-8",
                )
              _ =>
                event.res.headers.set(
                  "Content-Type", "text/plain;charset=UTF-8",
                )
            }
            response
          }
        }
        let body_str = match body {
          String(str) => str
          _ => body.stringify()
        }
        res.writeHead(
          event.res.statusCode,
          (try? @js.Value::from_json(event.res.headers.to_json())).or(
            @js.Object::new().to_value(),
          ),
        )
        res.end(body_str)
      })
    },
    port,
  )
}
