///|
/// Request-contract conformance suite.
///
/// These tests exercise the shared `dispatch_http` entry point, which every
/// backend (native, C/mongoose, JS) now funnels through, so the guarantees
/// below hold identically on the `+js` and `+native` targets (the workspace
/// runs the tests on both).
async test "query string does not break path routing" {
  let app = new()
  app.get("/hello", _ => "hello")
  let response = dispatch_http(app, "GET", "/hello?x=1", {}, b"")
  @test.assert_eq(response.status_code.to_int(), 200)
  let body : String = response.read_body()
  @test.assert_eq(body, "hello")
}

///|
async test "query string is exposed separately from the route path" {
  let app = new()
  let captured : Array[String] = []
  app.get("/hello/:name", event => {
    captured.push(event.req.url)
    captured.push(event.req.query)
    "ok"
  })
  ignore(dispatch_http(app, "GET", "/hello/moonbit?x=1&y=2", {}, b""))
  @test.assert_eq(captured, ["/hello/moonbit", "x=1&y=2"])
}

///|
async test "fragment is stripped from the query string" {
  let app = new()
  let captured : Array[String] = []
  app.get("/hello", event => {
    captured.push(event.req.query)
    "ok"
  })
  ignore(dispatch_http(app, "GET", "/hello?a=1#frag", {}, b""))
  @test.assert_eq(captured, ["a=1"])
}

///|
async test "route with no query string yields an empty query" {
  let app = new()
  let captured : Array[String] = []
  app.get("/plain", event => {
    captured.push(event.req.query)
    "ok"
  })
  ignore(dispatch_http(app, "GET", "/plain", {}, b""))
  @test.assert_eq(captured, [""])
}

///|
async test "query parameters are URL-decoded and exposed via HttpRequest::query" {
  let app = new()
  let captured : Array[String] = []
  app.get("/search", event => {
    let q = event.req.query()
    captured.push(q.get("q").unwrap_or(""))
    captured.push(q.get("page").unwrap_or(""))
    captured.push(q.get("tag").unwrap_or(""))
    "ok"
  })
  ignore(
    dispatch_http(app, "GET", "/search?q=moon&page=2&tag=hello+world", {}, b""),
  )
  @test.assert_eq(captured, ["moon", "2", "hello world"])
}

///|
async test "PUT and PATCH bodies are delivered to the handler" {
  let app = new()
  let captured : Array[String] = []
  app.put("/raw1", event => {
    let text : String = event.req.body()
    captured.push(text)
    "accepted"
  })
  app.patch("/raw2", event => {
    let text : String = event.req.body()
    captured.push(text)
    "accepted"
  })
  ignore(dispatch_http(app, "PUT", "/raw1", {}, b"payload-put"))
  ignore(dispatch_http(app, "PATCH", "/raw2", {}, b"payload-patch"))
  @test.assert_eq(captured, ["payload-put", "payload-patch"])
}

///|
async test "request headers are case-insensitive" {
  let app = new()
  let captured : Array[StringView?] = []
  app.get("/hdr", event => {
    captured.push(event.req.headers.get("X-Test"))
    captured.push(event.req.headers.get("x-test"))
    captured.push(event.req.headers.get("X-TEST"))
    "ok"
  })
  let headers : Map[@http.CaseInsensitiveString, StringView] = Map([])
  headers["X-Test"] = "1"
  ignore(dispatch_http(app, "GET", "/hdr", headers, b""))
  @test.assert_eq(captured, [Some("1"), Some("1"), Some("1")])
}
