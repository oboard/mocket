///|
async test "security_headers sets all expected headers" {
  let event = MocketEvent::{
    req: HttpRequest::{
      http_method: "GET",
      url: "/test",
      headers: {},
      raw_body: b"",
    },
    res: HttpResponse::new(OK),
    params: {},
  }
  let mw = security_headers()
  let handler : HttpHandler = fn(_event) noraise { "ok" }
  let middlewares : Array[(String, Middleware)] = [("", mw)]
  ignore(execute_middlewares(middlewares, event, handler))
  inspect(
    event.res.headers.get("X-Content-Type-Options"),
    content="Some(\"nosniff\")",
  )
  inspect(event.res.headers.get("X-Frame-Options"), content="Some(\"DENY\")")
  inspect(event.res.headers.get("X-XSS-Protection"), content="Some(\"0\")")
  inspect(
    event.res.headers.get("Referrer-Policy"),
    content="Some(\"strict-origin-when-cross-origin\")",
  )
}

///|
async test "security_headers preserves handler response" {
  let event = MocketEvent::{
    req: HttpRequest::{
      http_method: "GET",
      url: "/hello",
      headers: {},
      raw_body: b"",
    },
    res: HttpResponse::new(OK),
    params: {},
  }
  let mw = security_headers()
  let handler : HttpHandler = fn(_event) noraise { "hello-response" }
  let middlewares : Array[(String, Middleware)] = [("", mw)]
  let result = execute_middlewares(middlewares, event, handler)
  let buf = @buffer.new()
  result.output(buf)
  inspect(@utf8.decode(buf.contents()), content="hello-response")
}
