///|
/// The continuation function passed to middleware, calling the next handler in the chain.
pub type MiddlewareNext = async () -> &Responder noraise

///|
/// A middleware function that receives a request event and a next continuation, and returns a response.
pub type Middleware = async (MocketEvent, MiddlewareNext) -> &Responder noraise

///|
fn normalize_middleware_base_path(base_path : String) -> String {
  if base_path == "" {
    ""
  } else if base_path.length() > 1 && base_path[base_path.length() - 1:] == "/" {
    base_path[:base_path.length() - 1].to_string()
  } else {
    base_path
  }
}

///|
/// Adds a middleware to the app, optionally scoped to a base path prefix.
pub fn Mocket::use_middleware(
  self : Mocket,
  middleware : Middleware,
  base_path? : String,
) -> Unit {
  let base_path = normalize_middleware_base_path(
    base_path.unwrap_or(self.base_path),
  )
  // Store middleware together with path scope
  self.middlewares.push((base_path, middleware))
}

///|
// Execute middleware chain with path matching (onion model)
async fn execute_middlewares(
  middlewares : Array[(String, Middleware)],
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
  // Fast path: no middleware registered
  if middlewares.is_empty() {
    return final_handler(event)
  }
  // Filter middlewares matching the request path
  let matched_middlewares = []
  let request_path = event.req.path()
  for mw in middlewares {
    let (base_path, middleware) = mw
    // Empty base_path means global middleware;
    // otherwise check if the request path matches the scope
    if base_path == "" || @mhttp.path_scope_matches(base_path, request_path) {
      matched_middlewares.push(middleware)
    }
  }
  // Fast path: no middleware matched this path
  if matched_middlewares.is_empty() {
    return final_handler(event)
  }
  // Build middleware chain recursively (onion model)
  execute_middleware_chain(matched_middlewares, 0, event, final_handler)
}

///|
// Recursively execute middleware chain
async fn execute_middleware_chain(
  middlewares : Array[Middleware],
  index : Int,
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
  if index >= middlewares.length() {
    // All middlewares executed: call the final handler
    final_handler(event)
  } else {
    // Execute current middleware
    let current_middleware = middlewares[index]
    let next = async fn() noraise {
      execute_middleware_chain(middlewares, index + 1, event, final_handler)
    }
    current_middleware(event, next)
  }
}
