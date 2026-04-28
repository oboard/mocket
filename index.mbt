///|
pub(all) struct MultipartFormValue {
  filename : String?
  content_type : String?
  data : BytesView
}

///|
#alias(T)
pub(all) struct Mocket {
  base_path : String
  mappings : Map[(String, String), HttpHandler]
  middlewares : Array[(String, Middleware)]
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
}

///|
pub fn new(base_path? : String = "") -> Mocket {
  {
    base_path,
    mappings: {},
    middlewares: [],
    static_routes: {},
    dynamic_routes: {},
    ws_static_routes: {},
    ws_dynamic_routes: [],
    ws_clients: {},
    ws_channels: {},
    ws_client_port: {},
  }
}

///|

///|
pub(all) enum SameSiteOption {
  Lax
  Strict
  SameSiteNone
} derive(Eq)

///|
pub impl Show for SameSiteOption with output(self, logger) -> Unit {
  match self {
    Lax => logger.write_string("Lax")
    Strict => logger.write_string("Strict")
    SameSiteNone => logger.write_string("SameSiteNone")
  }
}

///|
pub impl ToJson for SameSiteOption with to_json(self : SameSiteOption) -> Json {
  match self {
    Lax => "lax"
    Strict => "strict"
    SameSiteNone => "none"
  }
}

///|
pub(all) struct CookieItem {
  name : String
  value : String
  max_age : Int?
  path : String?
  domain : String?
  secure : Bool?
  http_only : Bool?
  same_site : SameSiteOption?
} derive(Eq)

///|
pub impl Show for CookieItem with output(self, logger) -> Unit {
  logger.write_string(self.name)
  logger.write_char('=')
  logger.write_string(self.value)
  if self.max_age is Some(max_age) {
    logger.write_string("; Max-Age=")
    logger.write_string(max_age.to_string())
  }
  if self.path is Some(path) {
    logger.write_string("; Path=")
    logger.write_string(path)
  }
  if self.domain is Some(domain) {
    logger.write_string("; Domain=")
    logger.write_string(domain)
  }
  if self.secure == Some(true) {
    logger.write_string("; Secure")
  }
  if self.http_only == Some(true) {
    logger.write_string("; HttpOnly")
  }
  if self.same_site is Some(same_site) {
    logger.write_string("; SameSite=")
    logger.write_string(same_site.to_string())
  }
}

///|
pub impl Show for CookieItem with to_string(self : CookieItem) -> String {
  let buf = @buffer.new()
  self.output(buf)
  buf.to_string()
}

///|
pub fn Mocket::on(
  self : Mocket,
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
        let new_routes : Map[String, HttpHandler] = {}
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
pub fn Mocket::get(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn Mocket::post(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn Mocket::patch(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn Mocket::connect(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn Mocket::put(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn Mocket::delete(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn Mocket::head(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn Mocket::options(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn Mocket::trace(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn Mocket::acl(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("ACL", path, handler)
}

///|
pub fn Mocket::bind(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("BIND", path, handler)
}

///|
pub fn Mocket::checkin(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("CHECKIN", path, handler)
}

///|
pub fn Mocket::checkout(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("CHECKOUT", path, handler)
}

///|
pub fn Mocket::copy(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("COPY", path, handler)
}

///|
pub fn Mocket::label(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("LABEL", path, handler)
}

///|
pub fn Mocket::link(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("LINK", path, handler)
}

///|
pub fn Mocket::lock(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("LOCK", path, handler)
}

///|
pub fn Mocket::merge(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MERGE", path, handler)
}

///|
pub fn Mocket::mkactivity(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKACTIVITY", path, handler)
}

///|
pub fn Mocket::mkcalendar(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKCALENDAR", path, handler)
}

///|
pub fn Mocket::mkcol(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKCOL", path, handler)
}

///|
pub fn Mocket::mkredirectref(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKREDIRECTREF", path, handler)
}

///|
pub fn Mocket::mkworkspace(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MKWORKSPACE", path, handler)
}

///|
pub fn Mocket::move_(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("MOVE", path, handler)
}

///|
pub fn Mocket::orderpatch(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("ORDERPATCH", path, handler)
}

///|
pub fn Mocket::pri(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("PRI", path, handler)
}

///|
pub fn Mocket::propfind(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PROPFIND", path, handler)
}

///|
pub fn Mocket::proppatch(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PROPPATCH", path, handler)
}

///|
pub fn Mocket::query(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("QUERY", path, handler)
}

///|
pub fn Mocket::rebind(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("REBIND", path, handler)
}

///|
pub fn Mocket::report(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("REPORT", path, handler)
}

///|
pub fn Mocket::search(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("SEARCH", path, handler)
}

///|
pub fn Mocket::unbind(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UNBIND", path, handler)
}

///|
pub fn Mocket::uncheckout(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UNCHECKOUT", path, handler)
}

///|
pub fn Mocket::unlink(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UNLINK", path, handler)
}

///|
pub fn Mocket::unlock(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UNLOCK", path, handler)
}

///|
pub fn Mocket::update(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UPDATE", path, handler)
}

///|
pub fn Mocket::updateredirectref(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("UPDATEREDIRECTREF", path, handler)
}

///|
pub fn Mocket::version_control(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("VERSION-CONTROL", path, handler)
}

///|
pub fn Mocket::all(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("*", path, handler)
}

///|
// 创建路由组
pub fn Mocket::group(
  self : Mocket,
  base_path : String,
  configure : (Mocket) -> Unit,
) -> Unit {
  let group = new(base_path=self.base_path + base_path)
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
  self.middlewares.append(group.middlewares)
}

///|
// 注册 WebSocket 路由（不区分方法，按路径匹配）
pub fn Mocket::ws(
  self : Mocket,
  path : String,
  handler : WebSocketHandler,
) -> Unit {
  let path = self.base_path + path
  // 静态路径直接缓存
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    self.ws_static_routes.set(path, handler)
  } else {
    // 动态路径加入列表
    self.ws_dynamic_routes.push((path, handler))
  }
}
