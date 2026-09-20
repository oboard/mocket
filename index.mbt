///|
pub(all) struct MultipartFormValue {
  filename : String?
  content_type : String?
  data : BytesView
}

///|
#alias(T)
#alias(Mocket)
pub(all) struct App {
  base_path : String
  mappings : Map[(String, String), HttpHandler]
  middlewares : Array[(String, Middleware)]
  priv middleware_trie : MiddlewareTrieNode
  priv dynamic_route_tries : Map[String, DynamicRouteTrieNode]
  // 添加静态路由缓存（精确匹配的路由）
  static_routes : Map[String, Map[String, HttpHandler]]
  // 添加动态路由缓存（包含参数的路由）
  dynamic_routes : Map[String, Array[(String, HttpHandler)]]
  // WebSocket 路由（按路径匹配，不区分方法）
  ws_static_routes : Map[String, WebSocketHandler]
  ws_dynamic_routes : Array[(String, WebSocketHandler)]
  ws_clients : Map[String, Unit]
  ws_channels : Map[String, Map[String, Unit]]
  ws_client_port : Map[String, Int]
  max_body_size : Int
  mut error_handler : ErrorHandler
}

///|
#deprecated("Use `App()` instead")
pub fn new(base_path? : String = "", max_body_size? : Int = 1048576) -> App {
  App(base_path~, max_body_size~)
}

///|
#alias(new, deprecated="Use `App()` instead")
pub fn App::App(
  base_path? : String = "",
  max_body_size? : Int = 1048576,
) -> App {
  {
    base_path,
    mappings: {},
    middlewares: [],
    middleware_trie: new_middleware_trie_node(),
    dynamic_route_tries: {},
    static_routes: {},
    dynamic_routes: {},
    ws_static_routes: {},
    ws_dynamic_routes: [],
    ws_clients: {},
    ws_channels: {},
    ws_client_port: {},
    max_body_size,
    error_handler: default_error_handler,
  }
}

///|
pub fn App::on(
  self : App,
  event : String,
  path : String,
  handler : HttpHandler,
) -> Unit {
  let path = self.base_path + path
  self.mappings.set((event, path), handler)

  // 优化：根据路径类型分别缓存
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    // 静态路径，直接缓存
    match self.static_routes.get(event) {
      Some(http_methodroutes) => http_methodroutes.set(path, handler)
      None => {
        let new_routes : Map[String, HttpHandler] = Map([])
        new_routes.set(path, handler)
        self.static_routes.set(event, new_routes)
      }
    }
  } else {
    self.insert_dynamic_route(event, path, handler)
  }
}

///|
pub fn App::get(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn App::post(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn App::patch(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn App::connect(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn App::put(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn App::delete(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn App::head(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn App::options(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn App::trace(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn App::acl(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("ACL", path, handler)
}

///|
pub fn App::bind(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("BIND", path, handler)
}

///|
pub fn App::checkin(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("CHECKIN", path, handler)
}

///|
pub fn App::checkout(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("CHECKOUT", path, handler)
}

///|
pub fn App::copy(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("COPY", path, handler)
}

///|
pub fn App::label(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("LABEL", path, handler)
}

///|
pub fn App::link(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("LINK", path, handler)
}

///|
pub fn App::lock(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("LOCK", path, handler)
}

///|
pub fn App::merge(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("MERGE", path, handler)
}

///|
pub fn App::mkactivity(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKACTIVITY", path, handler)
}

///|
pub fn App::mkcalendar(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKCALENDAR", path, handler)
}

///|
pub fn App::mkcol(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("MKCOL", path, handler)
}

///|
pub fn App::mkredirectref(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKREDIRECTREF", path, handler)
}

///|
pub fn App::mkworkspace(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKWORKSPACE", path, handler)
}

///|
pub fn App::move_(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("MOVE", path, handler)
}

///|
pub fn App::orderpatch(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("ORDERPATCH", path, handler)
}

///|
pub fn App::pri(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("PRI", path, handler)
}

///|
pub fn App::propfind(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("PROPFIND", path, handler)
}

///|
pub fn App::proppatch(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("PROPPATCH", path, handler)
}

///|
pub fn App::query(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("QUERY", path, handler)
}

///|
pub fn App::rebind(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("REBIND", path, handler)
}

///|
pub fn App::report(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("REPORT", path, handler)
}

///|
pub fn App::search(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("SEARCH", path, handler)
}

///|
pub fn App::unbind(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("UNBIND", path, handler)
}

///|
pub fn App::uncheckout(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UNCHECKOUT", path, handler)
}

///|
pub fn App::unlink(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("UNLINK", path, handler)
}

///|
pub fn App::unlock(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("UNLOCK", path, handler)
}

///|
pub fn App::update(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("UPDATE", path, handler)
}

///|
pub fn App::updateredirectref(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UPDATEREDIRECTREF", path, handler)
}

///|
pub fn App::version_control(
  self : App,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("VERSION-CONTROL", path, handler)
}

///|
pub fn App::all(self : App, path : String, handler : HttpHandler) -> Unit {
  self.on("*", path, handler)
}

///|
// 创建路由组
pub fn App::group(
  self : App,
  base_path : String,
  configure : (App) -> Unit,
) -> Unit {
  let group = App(base_path=self.base_path + base_path)
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
    i.1.each(route => self.insert_dynamic_route(event, route.0, route.1))
  })
  // 合并中间件
  group.middlewares.each(middleware => {
    let (base_path, middleware) = middleware
    self.use_middleware(middleware, base_path~)
  })
}

///|
// 注册 WebSocket 路由（不区分方法，按路径匹配）
pub fn App::ws(self : App, path : String, handler : WebSocketHandler) -> Unit {
  let path = self.base_path + path
  // 静态路径直接缓存
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    self.ws_static_routes.set(path, handler)
  } else {
    // 动态路径加入列表
    self.ws_dynamic_routes.push((path, handler))
  }
}
