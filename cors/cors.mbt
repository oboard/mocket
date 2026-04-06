/// Determines whether an incoming request is a CORS preflight request by checking
/// for the OPTIONS method, an `Origin` header, and an `Access-Control-Request-Method` header.

///|
pub fn is_preflight_request(event : @crescent.MocketEvent) -> Bool {
  let origin = event.req.get_header("origin")
  let access_control_request_method = event.req.get_header(
    "access-control-request-method",
  )
  return event.req.http_method == Options &&
    origin != None &&
    access_control_request_method != None
}

/// Appends CORS preflight response headers (`Access-Control-Allow-Origin`,
/// `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`,
/// `Access-Control-Max-Age`, and optionally `Access-Control-Allow-Credentials`)
/// to the event's response.

///|
pub fn append_cors_preflight_headers(
  event : @crescent.MocketEvent,
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  credentials? : Bool = false,
  max_age? : Int = 86400,
) -> Unit noraise {
  let headers = event.res.headers
  headers["Access-Control-Allow-Origin"] = origin
  if credentials {
    headers["Access-Control-Allow-Credentials"] = "true"
  }
  headers["Access-Control-Allow-Methods"] = methods
  headers["Access-Control-Allow-Headers"] = allow_headers
  headers["Access-Control-Max-Age"] = max_age.to_string()
}

/// Appends standard CORS response headers (`Access-Control-Allow-Origin`,
/// `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`,
/// `Access-Control-Expose-Headers`, and optionally `Access-Control-Allow-Credentials`)
/// to the event's response for non-preflight requests.

///|
pub fn append_cors_headers(
  event : @crescent.MocketEvent,
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  expose_headers? : String = "*",
  credentials? : Bool = false,
) -> Unit noraise {
  let headers = event.res.headers
  headers["Access-Control-Allow-Origin"] = origin
  headers["Access-Control-Allow-Methods"] = methods
  headers["Access-Control-Allow-Headers"] = allow_headers
  headers["Access-Control-Expose-Headers"] = expose_headers
  if credentials {
    headers["Access-Control-Allow-Credentials"] = "true"
  }
}

/// Returns a middleware that handles CORS for both preflight and regular requests.
/// Preflight requests receive an empty 200 response with appropriate headers;
/// regular requests have CORS headers appended before continuing the middleware chain.

///|
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
      @crescent.HttpResponse::new(OK).to_responder()
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
