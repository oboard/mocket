///|
pub fn is_preflight_request(event : @mocket.HttpEvent) -> Bool {
  let origin = event.req.headers.get("origin")
  let access_control_request_method = event.req.headers.get(
    "access-control-request-method",
  )
  return event.req.http_method == "OPTIONS" &&
    origin != None &&
    access_control_request_method != None
}

///|
pub fn append_cors_preflight_headers(
  event : @mocket.HttpEvent,
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

///|
pub fn append_cors_headers(
  event : @mocket.HttpEvent,
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

///|
pub fn handle_cors(
  origin? : String = "*",
  methods? : String = "*",
  allow_headers? : String = "*",
  expose_headers? : String = "*",
  credentials? : Bool = false,
  max_age? : Int = 86400,
) -> @mocket.Middleware {
  (event, next) => if is_preflight_request(event) {
    append_cors_preflight_headers(
      event,
      origin~,
      methods~,
      allow_headers~,
      credentials~,
      max_age~,
    )
    // 对于预检请求，直接返回空响应，不调用next()
    @mocket.Empty
  } else {
    append_cors_headers(
      event,
      origin~,
      methods~,
      allow_headers~,
      expose_headers~,
      credentials~,
    )
    // 对于普通请求，继续执行后续中间件和处理器
    next()
  }
}
