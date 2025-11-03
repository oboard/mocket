///|
pub(all) enum HttpBody {
  Json(Json)
  Text(StringView)
  HTML(StringView)
  Bytes(BytesView)
  Empty
}

///|
pub(all) struct Mocket {
  base_path : String
  mappings : Map[(String, String), async (HttpEvent) -> HttpBody noraise]
  middlewares : Array[(String, Middleware)]
  // 添加静态路由缓存（精确匹配的路由）
  static_routes : Map[
    String,
    Map[String, async (HttpEvent) -> HttpBody noraise],
  ]
  // 添加动态路由缓存（包含参数的路由）
  dynamic_routes : Map[
    String,
    Array[(String, async (HttpEvent) -> HttpBody noraise)],
  ]
  // 日志记录器
  logger : Logger
}

///|
pub typealias Mocket as T

///|
pub fn new(
  base_path? : String = "",
  logger? : Logger = new_production_logger(),
) -> Mocket {
  {
    base_path,
    mappings: {},
    middlewares: [],
    static_routes: {},
    dynamic_routes: {},
    logger,
  }
}

///|
pub(all) struct HttpRequest {
  http_method : String
  url : String
  headers : Map[String, String]
  mut body : HttpBody
}

///|
pub(all) struct HttpResponse {
  mut status_code : Int
  headers : Map[StringView, StringView]
  // body : Body
}

///|
pub fn Mocket::on(
  self : Mocket,
  event : String,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  let path = self.base_path + path
  self.logger.route_register(event, path)
  self.mappings.set((event, path), handler)

  // 优化：根据路径类型分别缓存
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    // 静态路径，直接缓存
    self.logger.route_static(event, path)
    match self.static_routes.get(event) {
      Some(http_methodroutes) => {
        self.logger.route_merge_existing(event)
        http_methodroutes.set(path, handler)
        self.logger.route_added(path)
      }
      None => {
        self.logger.route_merge_new(event)
        let new_routes : Map[String, async (HttpEvent) -> HttpBody noraise] = {}
        new_routes.set(path, handler)
        self.static_routes.set(event, new_routes)
        self.logger.route_created(path)
      }
    }
  } else {
    // 动态路径，加入动态路由列表
    self.logger.route_dynamic(event, path)
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
pub fn Mocket::get(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn Mocket::post(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn Mocket::patch(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn Mocket::connect(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn Mocket::put(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn Mocket::delete(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn Mocket::head(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn Mocket::options(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn Mocket::trace(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn Mocket::all(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> HttpBody noraise,
) -> Unit {
  self.on("*", path, handler)
}

///|
// 创建路由组
pub fn Mocket::group(
  self : Mocket,
  base_path : String,
  configure : (Mocket) -> Unit,
) -> Unit {
  let group = new(base_path=self.base_path + base_path, logger=self.logger)
  configure(group)
  // 合并路由
  group.mappings.iter().each(i => self.mappings.set(i.0, i.1))
  group.static_routes
  .iter()
  .each(i => {
    let http_method = i.0
    let group_routes = i.1
    match self.static_routes.get(http_method) {
      Some(existing_routes) =>
        group_routes.iter().each(route => existing_routes.set(route.0, route.1))
      None => self.static_routes.set(http_method, group_routes)
    }
  })
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
