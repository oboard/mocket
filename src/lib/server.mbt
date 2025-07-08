///|
pub suberror IOError derive(Show)

///|
pub suberror NetworkError derive(Show)

///|
pub suberror ExecError derive(Show)

///|
pub fn run(f : async () -> Unit) -> Unit = "%async.run"

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
  ) -> Unit
) -> T raise E = "%async.suspend"

///|
pub(all) struct Mocket {
  mappings : Map[(String, String), async (HttpEvent) -> Json]
  middlewares : Array[async (HttpEvent) -> Unit]
}

///|
pub typealias Mocket as T

///|
pub fn new() -> Mocket {
  { mappings: {}, middlewares: [] }
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
  // 将 :param 替换为 ([^/]+)，将 * 替换为 (.*)，将 ** 替换为 (.*)
  let parts = template.split("/").to_array()
  let mut i = 0
  while i < parts.length() {
    let part = parts[i].to_string()
    if part.find(":").or(-1) == 0 {
      parts[i] = "([^/]+)"
    } else if part == "*" {
      parts[i] = "([^/]+)"
    } else if part == "**" {
      parts[i] = "(.*)"
    }
    i = i + 1
  }
  "^" + parts.map(fn(p) { p.to_string() }).join("/") + "$"
}

///|
// 匹配路径并提取参数
fn matchPath(template : String, path : String) -> Map[String, String]? {
  // 如果模板中没有参数和通配符，直接比较
  if template.find(":").or(-1) == -1 && template.find("*").or(-1) == -1 {
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
    if part.find(":").or(-1) == 0 {
      param_names.push(part.charcodes(start=1).to_string())
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
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.mappings.set((event, path), handler)
}

///|
pub fn get(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn post(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn patch(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn connect(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn put(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn delete(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn head(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn options(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn trace(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn all(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("*", path, handler)
}

///|
// 注册全局中间件
pub fn use_middleware(
  self : Mocket,
  middleware : async (HttpEvent) -> Unit
) -> Unit {
  self.middlewares.push(middleware)
}

///|
// 执行中间件链
fn executeMiddlewares(
  middlewares : Array[async (HttpEvent) -> Unit],
  event : HttpEvent,
  index : Int
) -> Unit {
  if index >= middlewares.length() {
    return
  }
  let middleware = middlewares[index]
  run(fn() {
    middleware(event)
    executeMiddlewares(middlewares, event, index + 1)
  })
}

///|
// 查找匹配的路由和参数
fn findRoute(
  self : Mocket,
  reqMethod : String,
  path : String
) -> (async (HttpEvent) -> Json, Map[String, String])? {
  // 首先尝试精确匹配
  match self.mappings.get((reqMethod, path)) {
    Some(handler) => Some((handler, {}))
    None =>
      // 尝试通配符方法匹配
      match self.mappings.get(("*", path)) {
        Some(handler) => Some((handler, {}))
        None => {
          // 然后尝试参数匹配
          for route_key, handler in self.mappings {
            let (route_method, route_path) = route_key
            if route_method == reqMethod || route_method == "*" {
              match matchPath(route_path, path) {
                Some(params) => return Some((handler, params))
                None => ignore(())
              }
            }
          }
          None
        }
      }
  }
}

///|
pub fn serve(self : Mocket, port~ : Int) -> Unit {
  createServer(
    fn(req, res, _) {
      guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
        res.writeHead(400, @js.Object::new().to_value())
        res.end("Invalid headers")
        return
      }

      // 将 JSON headers 转换为字符串 headers
      let string_headers = {}
      headers.each(fn(key, value) {
        if value is String(v) {
          string_headers.set(key, v)
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
        executeMiddlewares(self.middlewares, event, 0)
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
