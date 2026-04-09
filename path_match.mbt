///|
fn Mocket::find_route_for_method(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  if self.static_routes.get(http_method) is Some(method_routes) {
    if method_routes.get(path) is Some(handler) {
      return Some((handler, {}))
    }
  }
  match self.dynamic_routes.search(http_method, path) {
    Some((handler, params)) => return Some((handler, params))
    None => ()
  }
  None
}

///|
fn Mocket::has_route_for_method(
  self : Mocket,
  http_method : String,
  path : String,
) -> Bool {
  self.find_route_for_method(http_method, path) is Some(_)
}

///|
fn Mocket::allowed_methods(
  self : Mocket,
  path : String,
  include_implicit_options : Bool,
) -> Array[String] {
  let allowed : Array[String] = []
  let supports_get = self.has_route_for_method("GET", path)
  let supports_head = self.has_route_for_method("HEAD", path)
  if supports_get {
    allowed.push("GET")
  }
  if supports_head || supports_get {
    allowed.push("HEAD")
  }
  for http_method in ["POST", "PUT", "PATCH", "DELETE"] {
    if self.has_route_for_method(http_method, path) {
      allowed.push(http_method)
    }
  }
  let supports_options = self.has_route_for_method("OPTIONS", path)
  if supports_options || (include_implicit_options && !allowed.is_empty()) {
    allowed.push("OPTIONS")
  }
  for http_method in ["TRACE", "CONNECT"] {
    if self.has_route_for_method(http_method, path) {
      allowed.push(http_method)
    }
  }
  allowed
}

///|
// Find matching route and parameters
fn Mocket::find_route(
  self : Mocket,
  http_method : String,
  path : String,
) -> (HttpHandler, Map[String, StringView])? {
  if self.find_route_for_method(http_method, path) is Some(route) {
    return Some(route)
  }
  if self.static_routes.get("*") is Some(wildcard_routes) {
    if wildcard_routes.get(path) is Some(handler) {
      return Some((handler, {}))
    }
  }
  match self.dynamic_routes.search("*", path) {
    Some((handler, params)) => return Some((handler, params))
    None => ()
  }
  None
}

///|
fn Mocket::find_ws_route(
  self : Mocket,
  path : String,
) -> (WebSocketHandler, Map[String, StringView])? {
  if self.ws_static_routes.get(path) is Some(handler) {
    return Some((handler, {}))
  }
  self.ws_dynamic_routes.search("WS", path)
}
