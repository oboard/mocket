/// The main application type that holds route mappings, middleware, and WebSocket handlers.

///|
pub struct Mocket {
  priv base_path : String
  priv mappings : Map[(String, String), HttpHandler]
  priv middlewares : Array[(String, Middleware)]
  priv static_routes : Map[String, Map[String, HttpHandler]]
  priv dynamic_routes : RadixRouter[HttpHandler]
  priv ws_static_routes : Map[String, WebSocketHandler]
  priv ws_dynamic_routes : Array[(CompiledRoute, WebSocketHandler)]
  priv ws_runtime_id : String
  priv mut not_found_handler : HttpHandler?

  fn new(base_path? : String) -> Mocket
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
pub fn Mocket::new(base_path? : String = "") -> Mocket {
  {
    base_path,
    mappings: {},
    middlewares: [],
    static_routes: {},
    dynamic_routes: RadixRouter::new(),
    ws_static_routes: {},
    ws_dynamic_routes: [],
    ws_runtime_id: next_mocket_instance_id(),
    not_found_handler: None,
  }
}

/// Returns an iterator over the registered route keys as `(method, path)` pairs.

///|
pub fn Mocket::routes(self : Mocket) -> Iter[(String, String)] {
  self.mappings.keys()
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
    // Dynamic path: compile and insert into radix tree
  } else {
    let compiled = CompiledRoute::compile(path)
    self.dynamic_routes.insert(event, compiled, handler)
  }
}

/// Registers a noraise GET handler. For most use cases, prefer `get()` which
/// provides automatic error handling.

///|
pub fn Mocket::get_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("GET", path, handler)
}

/// Registers a noraise POST handler.

///|
pub fn Mocket::post_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("POST", path, handler)
}

/// Registers a noraise PATCH handler.

///|
pub fn Mocket::patch_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PATCH", path, handler)
}

/// Registers a noraise CONNECT handler.

///|
pub fn Mocket::connect_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("CONNECT", path, handler)
}

/// Registers a noraise PUT handler.

///|
pub fn Mocket::put_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("PUT", path, handler)
}

/// Registers a noraise DELETE handler.

///|
pub fn Mocket::delete_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("DELETE", path, handler)
}

/// Registers a noraise HEAD handler.

///|
pub fn Mocket::head_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("HEAD", path, handler)
}

/// Registers a noraise OPTIONS handler.

///|
pub fn Mocket::options_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("OPTIONS", path, handler)
}

/// Registers a noraise TRACE handler.

///|
pub fn Mocket::trace_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
  self.on("TRACE", path, handler)
}

/// Registers a noraise handler that matches all HTTP methods.

///|
pub fn Mocket::all_raw(
  self : Mocket,
  path : String,
  handler : HttpHandler,
) -> Unit {
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
  let group = Mocket::new(base_path=self.base_path + base_path)
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
  self.dynamic_routes.merge(group.dynamic_routes)
  group.ws_static_routes.iter().each(i => self.ws_static_routes.set(i.0, i.1))
  self.ws_dynamic_routes.append(group.ws_dynamic_routes)
  // Merge middlewares
  self.middlewares.append(group.middlewares)
  // Merge not_found_handler (group's handler takes precedence if set)
  if group.not_found_handler is Some(_) {
    self.not_found_handler = group.not_found_handler
  }
}

/// Sets a custom handler for 404 Not Found responses.

///|
pub fn Mocket::set_not_found_handler(
  self : Mocket,
  handler : HttpHandler,
) -> Unit {
  self.not_found_handler = Some(handler)
}

/// Returns true if a custom not-found handler has been registered.

///|
pub fn Mocket::has_not_found_handler(self : Mocket) -> Bool {
  self.not_found_handler is Some(_)
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
  if !path.contains(":") && !path.contains("*") {
    self.ws_static_routes.set(path, handler)
  } else {
    // Dynamic path: compile pattern and add to list
    self.ws_dynamic_routes.push((CompiledRoute::compile(path), handler))
  }
}
