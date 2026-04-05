/// The main application type that holds route mappings, middleware, and WebSocket handlers.

///|
pub struct Mocket {
  base_path : String
  mappings : Map[(String, String), HttpHandler]
  middlewares : Array[(String, Middleware)]
  // Static route cache (exact match routes)
  static_routes : Map[String, Map[String, HttpHandler]]
  // Dynamic route cache (routes with parameters)
  dynamic_routes : Map[String, Array[(String, HttpHandler)]]
  // WebSocket routes (matched by path, method-agnostic)
  ws_static_routes : Map[String, WebSocketHandler]
  ws_dynamic_routes : Array[(String, WebSocketHandler)]
  ws_runtime_id : String
}

///|
let mocket_instance_counter : Ref[Int] = Ref::new(0)

///|
fn next_mocket_instance_id() -> String {
  mocket_instance_counter.val += 1
  "mocket-\{mocket_instance_counter.val}"
}

/// Creates a new Mocket application instance with an optional base path prefix.

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
    ws_runtime_id: next_mocket_instance_id(),
  }
}

///|

/// The SameSite attribute for cookies, controlling cross-site request behavior.

///|
pub(all) enum SameSiteOption {
  Lax
  Strict
  SameSiteNone
} derive(Debug, Eq)

///|
pub impl Show for SameSiteOption with output(self, logger) {
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

/// Represents an HTTP cookie with its name, value, and optional attributes.

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
fn sanitize_cookie_value(s : String) -> String {
  if s.contains("\r") || s.contains("\n") || s.contains(";") {
    let buf = StringBuilder::new()
    for c in s {
      if c != '\r' && c != '\n' && c != ';' {
        buf.write_char(c)
      }
    }
    buf.to_string()
  } else {
    s
  }
}

///|
pub impl Show for CookieItem with output(self, logger) -> Unit {
  logger.write_string(sanitize_cookie_value(self.name))
  logger.write_char('=')
  logger.write_string(sanitize_cookie_value(self.value))
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

/// Registers a route handler for the given HTTP method and path.

///|
pub fn Mocket::on(
  self : Mocket,
  event : String,
  path : String,
  handler : HttpHandler,
) -> Unit {
  let path = self.base_path + path
  self.mappings.set((event, path), handler)

  // Cache routes by path type for faster lookup
  if !path.contains(":") && !path.contains("*") {
    // Static path: cache directly
    if self.static_routes.get(event) is Some(method_routes) {
      method_routes.set(path, handler)
    } else {
      let new_routes : Map[String, HttpHandler] = Map::new()
      new_routes.set(path, handler)
      self.static_routes.set(event, new_routes)
    }
    // Dynamic path: add to dynamic route list
  } else if self.dynamic_routes.get(event) is Some(routes) {
    routes.push((path, handler))
  } else {
    self.dynamic_routes.set(event, [(path, handler)])
  }
}

/// Registers a handler for GET requests on the given path.

///|
pub fn Mocket::get(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("GET", path, handler)
}

/// Registers a handler for POST requests on the given path.

///|
pub fn Mocket::post(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("POST", path, handler)
}

/// Registers a handler for PATCH requests on the given path.

///|
pub fn Mocket::patch(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PATCH", path, handler)
}

/// Registers a handler for CONNECT requests on the given path.

///|
pub fn Mocket::connect(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("CONNECT", path, handler)
}

/// Registers a handler for PUT requests on the given path.

///|
pub fn Mocket::put(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("PUT", path, handler)
}

/// Registers a handler for DELETE requests on the given path.

///|
pub fn Mocket::delete(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("DELETE", path, handler)
}

/// Registers a handler for HEAD requests on the given path.

///|
pub fn Mocket::head(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("HEAD", path, handler)
}

/// Registers a handler for OPTIONS requests on the given path.

///|
pub fn Mocket::options(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("OPTIONS", path, handler)
}

/// Registers a handler for TRACE requests on the given path.

///|
pub fn Mocket::trace(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("TRACE", path, handler)
}

/// Registers a handler that matches all HTTP methods on the given path.

///|
pub fn Mocket::all(self : Mocket, path : String, handler : HttpHandler) -> Unit {
  self.on("*", path, handler)
}

/// Creates a route group with a shared base path prefix, merging its routes and middleware into the app.

///|
// Create route group
pub fn Mocket::group(
  self : Mocket,
  base_path : String,
  configure : (Mocket) -> Unit,
) -> Unit {
  let group = new(base_path=self.base_path + base_path)
  configure(group)
  // Merge routes
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
  group.ws_static_routes.iter().each(i => self.ws_static_routes.set(i.0, i.1))
  self.ws_dynamic_routes.append(group.ws_dynamic_routes)
  // Merge middlewares
  self.middlewares.append(group.middlewares)
}

/// Registers a WebSocket handler for the given path, matched regardless of HTTP method.

///|
// Register WebSocket route (method-agnostic, matched by path)
pub fn Mocket::ws(
  self : Mocket,
  path : String,
  handler : WebSocketHandler,
) -> Unit {
  let path = self.base_path + path
  // Static path: cache directly
  if path.find(":").unwrap_or(-1) == -1 && path.find("*").unwrap_or(-1) == -1 {
    self.ws_static_routes.set(path, handler)
  } else {
    // Dynamic path: add to list
    self.ws_dynamic_routes.push((path, handler))
  }
}
