///|
test "normalize_middleware_base_path with empty string" {
  inspect(normalize_middleware_base_path(""), content="")
}

///|
test "normalize_middleware_base_path with root slash" {
  inspect(normalize_middleware_base_path("/"), content="/")
}

///|
test "normalize_middleware_base_path strips trailing slash" {
  inspect(normalize_middleware_base_path("/api/"), content="/api")
}

///|
test "normalize_middleware_base_path keeps path without trailing slash" {
  inspect(normalize_middleware_base_path("/api"), content="/api")
}

///|
async test "empty middleware list calls final handler directly" {
  let event = MocketEvent::{
    req: HttpRequest(Get, "/test", {}, raw_body=b""),
    res: HttpResponse(OK),
    params: {},
  }
  let handler : HttpHandler = fn(_event) noraise { "handler-result" }
  let result = execute_middlewares([], event, handler)
  let buf = @buffer.new()
  result.output(buf)
  inspect(@utf8.decode(buf.contents()), content="handler-result")
}

///|
async test "single middleware wraps final handler" {
  let order : Array[String] = []
  let mw : Middleware = async fn(_event, next) noraise {
    order.push("mw-before")
    let result = next()
    order.push("mw-after")
    result
  }
  let event = MocketEvent::{
    req: HttpRequest(Get, "/test", {}, raw_body=b""),
    res: HttpResponse(OK),
    params: {},
  }
  let handler : HttpHandler = fn(_event) noraise {
    order.push("handler")
    "done"
  }
  let middlewares : Array[(String, Middleware)] = [("", mw)]
  ignore(execute_middlewares(middlewares, event, handler))
  inspect(
    order,
    content=(
      #|["mw-before", "handler", "mw-after"]
    ),
  )
}

///|
async test "multiple middlewares execute in onion model order" {
  let order : Array[String] = []
  let mw1 : Middleware = async fn(_event, next) noraise {
    order.push("mw1-before")
    let result = next()
    order.push("mw1-after")
    result
  }
  let mw2 : Middleware = async fn(_event, next) noraise {
    order.push("mw2-before")
    let result = next()
    order.push("mw2-after")
    result
  }
  let event = MocketEvent::{
    req: HttpRequest(Get, "/test", {}, raw_body=b""),
    res: HttpResponse(OK),
    params: {},
  }
  let handler : HttpHandler = fn(_event) noraise {
    order.push("handler")
    "done"
  }
  let middlewares : Array[(String, Middleware)] = [("", mw1), ("", mw2)]
  ignore(execute_middlewares(middlewares, event, handler))
  inspect(
    order,
    content=(
      #|["mw1-before", "mw2-before", "handler", "mw2-after", "mw1-after"]
    ),
  )
}

///|
async test "path-scoped middleware skips non-matching request" {
  let order : Array[String] = []
  let mw : Middleware = async fn(_event, next) noraise {
    order.push("api-mw")
    next()
  }
  let event = MocketEvent::{
    req: HttpRequest(Get, "/test", {}, raw_body=b""),
    res: HttpResponse(OK),
    params: {},
  }
  let handler : HttpHandler = fn(_event) noraise {
    order.push("handler")
    "done"
  }
  let middlewares : Array[(String, Middleware)] = [("/api", mw)]
  ignore(execute_middlewares(middlewares, event, handler))
  inspect(
    order,
    content=(
      #|["handler"]
    ),
  )
}

///|
async test "path-scoped middleware executes for matching request" {
  let order : Array[String] = []
  let mw : Middleware = async fn(_event, next) noraise {
    order.push("api-mw")
    next()
  }
  let event = MocketEvent::{
    req: HttpRequest(Get, "/api/users", {}, raw_body=b""),
    res: HttpResponse(OK),
    params: {},
  }
  let handler : HttpHandler = fn(_event) noraise {
    order.push("handler")
    "done"
  }
  let middlewares : Array[(String, Middleware)] = [("/api", mw)]
  ignore(execute_middlewares(middlewares, event, handler))
  inspect(
    order,
    content=(
      #|["api-mw", "handler"]
    ),
  )
}
