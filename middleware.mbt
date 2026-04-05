/// The continuation function passed to middleware, calling the next handler in the chain.

///|
pub type MiddlewareNext = async () -> &Responder noraise

/// A middleware function that receives a request event and a next continuation, and returns a response.

///|
// Middleware type: accepts HttpEvent and next function, returns HttpBody
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

/// Adds a middleware to the app, optionally scoped to a base path prefix.

///|
// Register middleware with path matching support
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

/// Executes the middleware chain using the onion model, filtering by path scope, then calls the final handler.

///|
// Execute middleware chain with path matching (onion model)
pub async fn execute_middlewares(
  middlewares : Array[(String, Middleware)],
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
  // Filter middlewares matching the request path
  let matched_middlewares = []
  let request_path = event.req.path()
  middlewares.each(middleware => {
    let (base_path, middleware) = middleware
    // Empty base_path means global middleware;
    // otherwise check if the request path matches the scope
    if base_path == "" || path_scope_matches(base_path, request_path) {
      matched_middlewares.push(middleware)
    }
  })

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
