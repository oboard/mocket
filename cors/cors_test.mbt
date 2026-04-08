///|
fn make_event(
  http_method : @crescent.HttpMethod,
  headers : Map[String, String],
) -> @crescent.MocketEvent {
  {
    req: @crescent.HttpRequest(http_method, "/resource", headers, raw_body=b""),
    res: @crescent.HttpResponse(OK),
    params: {},
  }
}

///|
test "origin=* with credentials=true reflects request origin" {
  let event = make_event(Get, { "origin": "https://myapp.com" })
  append_cors_headers(event, origin="*", credentials=true)
  assert_eq(
    event.res.headers.get("Access-Control-Allow-Origin"),
    Some("https://myapp.com"),
  )
  assert_eq(
    event.res.headers.get("Access-Control-Allow-Credentials"),
    Some("true"),
  )
  assert_eq(event.res.headers.get("Vary"), Some("Origin"))
}

///|
test "explicit origin is preserved with credentials" {
  let event = make_event(Get, { "origin": "https://myapp.com" })
  append_cors_headers(event, origin="https://allowed.com", credentials=true)
  assert_eq(
    event.res.headers.get("Access-Control-Allow-Origin"),
    Some("https://allowed.com"),
  )
}

///|
test "origin=* without credentials stays as *" {
  let event = make_event(Get, { "origin": "https://any.com" })
  append_cors_headers(event, origin="*", credentials=false)
  assert_eq(event.res.headers.get("Access-Control-Allow-Origin"), Some("*"))
}

///|
test "is_preflight_request requires cors headers and options" {
  inspect(
    is_preflight_request(
      make_event(Options, {
        "origin": "https://example.com",
        "access-control-request-method": "PUT",
      }),
    ),
    content="true",
  )
  inspect(
    is_preflight_request(
      make_event(Options, { "origin": "https://example.com" }),
    ),
    content="false",
  )
  inspect(
    is_preflight_request(
      make_event(Get, {
        "origin": "https://example.com",
        "access-control-request-method": "PUT",
      }),
    ),
    content="false",
  )
}

///|
suberror ServerNotReady

///|
suberror SocketBindUnavailable

///|
async fn allocate_test_server() -> @http.Server {
  let addr = @socket.Addr::parse("127.0.0.1:0") catch {
    _ => raise SocketBindUnavailable
  }
  let bind_check : Result[@http.Server, Error] = try? @http.Server::new(
    addr,
    reuse_addr=true,
  )
  match bind_check {
    Ok(server) => server
    Err(@os_error.OSError(errno, ..)) if errno == 1 =>
      raise SocketBindUnavailable
    Err(@os_error.OSError(_) as err) if err.is_EACCES() =>
      raise SocketBindUnavailable
    Err(err) => fail("unexpected bind check failure: \{err}")
  }
}

///|
fn localhost_url(port : Int, path : String) -> String {
  "http://127.0.0.1:\{port}\{path}"
}

///|
async fn wait_until_ready(port : Int) -> Unit {
  @async.retry(FixedDelay(20), max_retry=50, () => {
    let (response, _body) = @http.get(localhost_url(port, "/__cors_ready"))
    guard response.code == 200 else { raise ServerNotReady }
  })
}

///|
async fn with_test_server(
  app : @crescent.Mocket,
  run_test : async (Int) -> Unit,
) -> Unit {
  let server = allocate_test_server()
  let port = server.addr.port()
  app.get("/__cors_ready", _ => "ready")
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => app.serve_on(server))
    wait_until_ready(port)
    run_test(port)
  })
}

///|
async fn issue_request(
  port : Int,
  meth : @http.RequestMethod,
  path : String,
  headers? : Map[String, String],
) -> (@http.Response, Bytes) {
  let client = @http.Client::new("http://127.0.0.1:\{port}")
  defer client.close()
  client.request(meth, path, extra_headers=headers.unwrap_or({}))
  let response = client.end_request()
  let response_body = client.read_all().binary()
  (response, response_body)
}

///|
async fn issue_raw_request_headers(port : Int, request : String) -> String {
  let addr = @socket.Addr::parse("127.0.0.1:\{port}") catch {
    _ => fail("invalid raw request address")
  }
  let client = @socket.Tcp::connect(addr)
  defer client.close()
  client.write(request)
  client.read_until("\r\n\r\n").unwrap_or("")
}

///|
async test "handle_cors serves preflight requests through async server" {
  let handler_called = Ref::new(false)
  let app = @crescent.Mocket()
  app.use_middleware(
    handle_cors(
      origin="https://frontend.example",
      methods="GET, PATCH",
      allow_headers="Content-Type, Authorization",
      credentials=true,
      max_age=7200,
    ),
  )
  app.options("/resource", _ => {
    handler_called.val = true
    @crescent.text("unexpected")
  })
  with_test_server(app, port => {
    let (response, body) = issue_request(port, Options, "/resource", headers={
      "origin": "https://frontend.example",
      "access-control-request-method": "PATCH",
    })
    assert_eq(response.code, 200)
    assert_eq(body, b"")
    assert_eq(
      response.headers.get("access-control-allow-origin"),
      Some("https://frontend.example"),
    )
    assert_eq(
      response.headers.get("access-control-allow-methods"),
      Some("GET, PATCH"),
    )
    assert_eq(
      response.headers.get("access-control-allow-headers"),
      Some("Content-Type, Authorization"),
    )
    assert_eq(
      response.headers.get("access-control-allow-credentials"),
      Some("true"),
    )
    assert_eq(response.headers.get("access-control-max-age"), Some("7200"))
    inspect(handler_called.val, content="false")
  })
}

///|
async test "handle_cors decorates normal requests through async server" {
  let app = @crescent.Mocket()
  app.use_middleware(
    handle_cors(
      origin="https://frontend.example",
      methods="GET, POST",
      allow_headers="Content-Type",
      expose_headers="X-Trace-Id",
      credentials=true,
    ),
  )
  app.get("/resource", _ => "ok")
  with_test_server(app, port => {
    let (response, body) = issue_request(port, Get, "/resource", headers={
      "origin": "https://frontend.example",
    })
    assert_eq(response.code, 200)
    assert_eq(@utf8.decode(body) catch { _ => "" }, "ok")
    assert_eq(
      response.headers.get("access-control-allow-origin"),
      Some("https://frontend.example"),
    )
    assert_eq(
      response.headers.get("access-control-allow-methods"),
      Some("GET, POST"),
    )
    assert_eq(
      response.headers.get("access-control-allow-headers"),
      Some("Content-Type"),
    )
    assert_eq(
      response.headers.get("access-control-expose-headers"),
      Some("X-Trace-Id"),
    )
    assert_eq(
      response.headers.get("access-control-allow-credentials"),
      Some("true"),
    )
  })
}

///|
async test "handle_cors does not short-circuit non-preflight options" {
  let handler_called = Ref::new(false)
  let app = @crescent.Mocket()
  app.use_middleware(
    handle_cors(
      origin="https://frontend.example",
      methods="GET, OPTIONS",
      allow_headers="Content-Type",
      expose_headers="X-Trace-Id",
      credentials=true,
    ),
  )
  app.options("/resource", _ => {
    handler_called.val = true
    @crescent.text("regular-options")
  })
  with_test_server(app, port => {
    let (response, body) = issue_request(port, Options, "/resource", headers={
      "origin": "https://frontend.example",
    })
    assert_eq(response.code, 200)
    assert_eq(@utf8.decode(body) catch { _ => "" }, "regular-options")
    assert_eq(
      response.headers.get("access-control-allow-origin"),
      Some("https://frontend.example"),
    )
    assert_eq(
      response.headers.get("access-control-allow-methods"),
      Some("GET, OPTIONS"),
    )
    assert_eq(
      response.headers.get("access-control-allow-headers"),
      Some("Content-Type"),
    )
    assert_eq(
      response.headers.get("access-control-expose-headers"),
      Some("X-Trace-Id"),
    )
    assert_eq(
      response.headers.get("access-control-allow-credentials"),
      Some("true"),
    )
    assert_eq(response.headers.get("access-control-max-age"), None)
    inspect(handler_called.val, content="true")
  })
}

///|
async test "handle_cors accepts mixed-case preflight headers" {
  let app = @crescent.Mocket()
  app.use_middleware(
    handle_cors(
      origin="https://frontend.example",
      methods="GET, PATCH",
      allow_headers="Content-Type, Authorization",
      credentials=true,
      max_age=7200,
    ),
  )
  app.options("/resource", _ => @crescent.text("unexpected"))
  with_test_server(app, port => {
    let response_headers = issue_raw_request_headers(
      port, "OPTIONS /resource HTTP/1.1\r\nHost: localhost\r\nOrIgIn: https://frontend.example\r\nAcCeSs-CoNtRoL-ReQuEsT-MeThOd: PATCH\r\nConnection: close\r\n\r\n",
    )
    assert_true(response_headers.has_prefix("HTTP/1.1 200 "))
    assert_true(
      response_headers.contains(
        "Access-Control-Allow-Origin: https://frontend.example",
      ),
    )
    assert_true(
      response_headers.contains("Access-Control-Allow-Methods: GET, PATCH"),
    )
    assert_true(
      response_headers.contains(
        "Access-Control-Allow-Headers: Content-Type, Authorization",
      ),
    )
    assert_true(
      response_headers.contains("Access-Control-Allow-Credentials: true"),
    )
    assert_true(response_headers.contains("Access-Control-Max-Age: 7200"))
  })
}
