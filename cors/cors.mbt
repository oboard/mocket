///|
/// Determines whether an incoming request is a CORS preflight request by checking
/// for the OPTIONS method, an `Origin` header, and an `Access-Control-Request-Method` header.
pub fn is_preflight_request(event : @crescent.MocketEvent) -> Bool {
  let origin = event.req.get_header("origin")
  let access_control_request_method = event.req.get_header(
    "access-control-request-method",
  )
  return event.req.http_method == Options &&
    origin != None &&
    access_control_request_method != None
}

/// Resolves the `Access-Control-Allow-Origin` value. When `credentials=true`
/// and the configured origin is `"*"`, reflects the request's Origin header
/// instead (since browsers reject `*` with credentials). Also sets `Vary: Origin`
/// so intermediate caches don't serve the wrong origin.

///|
fn resolve_allow_origin(
  event : @crescent.MocketEvent,
  configured_origin : String,
  credentials : Bool,
) -> String noraise {
  if credentials && configured_origin == "*" {
    // Reflect the request origin; browsers reject ACAO:* with credentials.
    let headers = event.res.headers
    // Add Vary: Origin so caches don't serve the wrong origin.
    match headers.get("Vary") {
      Some(existing) =>
        if !existing.contains("Origin") {
          headers["Vary"] = existing + ", Origin"
        }
      None => headers["Vary"] = "Origin"
    }
    match event.req.get_header("origin") {
      Some(origin) => origin
      None => "*" // fallback; browser will reject but we did our best
    }
  } else {
    configured_origin
  }
}

///|
/// Appends CORS preflight response headers (`Access-Control-Allow-Origin`,
/// `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`,
/// `Access-Control-Max-Age`, and optionally `Access-Control-Allow-Credentials`)
/// to the event's response.
///
/// When `credentials=true` and `origin="*"`, the request Origin is reflected
/// instead (browsers reject `*` with credentials) and `Vary: Origin` is set.
pub fn append_cors_preflight_headers(
  event : @crescent.MocketEvent,
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  credentials? : Bool = false,
  max_age? : Int = 86400,
) -> Unit noraise {
  let headers = event.res.headers
  headers["Access-Control-Allow-Origin"] = resolve_allow_origin(
    event, origin, credentials,
  )
  if credentials {
    headers["Access-Control-Allow-Credentials"] = "true"
  }
  headers["Access-Control-Allow-Methods"] = methods
  headers["Access-Control-Allow-Headers"] = allow_headers
  headers["Access-Control-Max-Age"] = max_age.to_string()
}

///|
/// Appends standard CORS response headers (`Access-Control-Allow-Origin`,
/// `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`,
/// `Access-Control-Expose-Headers`, and optionally `Access-Control-Allow-Credentials`)
/// to the event's response for non-preflight requests.
pub fn append_cors_headers(
  event : @crescent.MocketEvent,
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  expose_headers? : String = "*",
  credentials? : Bool = false,
) -> Unit noraise {
  let headers = event.res.headers
  headers["Access-Control-Allow-Origin"] = resolve_allow_origin(
    event, origin, credentials,
  )
  headers["Access-Control-Allow-Methods"] = methods
  headers["Access-Control-Allow-Headers"] = allow_headers
  headers["Access-Control-Expose-Headers"] = expose_headers
  if credentials {
    headers["Access-Control-Allow-Credentials"] = "true"
  }
}

///|
/// Returns a middleware that handles CORS for both preflight and regular requests.
/// Preflight requests receive an empty 200 response with appropriate headers;
/// regular requests have CORS headers appended before continuing the middleware chain.
pub fn handle_cors(
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  expose_headers? : String = "*",
  credentials? : Bool = false,
  max_age? : Int = 86400,
) -> @crescent.Middleware {
  (event, next) => {
    if is_preflight_request(event) {
      append_cors_preflight_headers(
        event,
        origin~,
        methods~,
        allow_headers~,
        credentials~,
        max_age~,
      )
      // For preflight requests, return empty response without calling next()
      @crescent.HttpResponse(OK).to_responder()
    } else {
      append_cors_headers(
        event,
        origin~,
        methods~,
        allow_headers~,
        expose_headers~,
        credentials~,
      )
      // For regular requests, continue executing subsequent middleware and handlers
      next()
    }
  }
}
