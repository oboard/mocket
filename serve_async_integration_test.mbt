///|
struct TestStaticProvider {}

///|
struct EncodedStaticProvider {}

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
impl ServeStaticProvider for TestStaticProvider with get_meta(_, id) {
  match id {
    "" =>
      Some(StaticAssetMeta::new(asset_type="text/html; charset=utf-8", size=5L))
    "hello.txt" =>
      Some(
        StaticAssetMeta::new(asset_type="text/plain; charset=utf-8", size=2L),
      )
    _ => None
  }
}

///|
impl ServeStaticProvider for TestStaticProvider with get_contents(_, id) {
  match id {
    "" => html("index")
    "hello.txt" => text("hi")
    _ => HttpResponse::new(NotFound).body("Not Found")
  }
}

///|
impl ServeStaticProvider for TestStaticProvider with get_type(_, _ext) -> String? {
  None
}

///|
impl ServeStaticProvider for TestStaticProvider with get_encodings(_) -> Map[
  String,
  String,
] {
  {}
}

///|
impl ServeStaticProvider for TestStaticProvider with get_index_names(_) -> Array[
  String,
] {
  ["index.html"]
}

///|
impl ServeStaticProvider for TestStaticProvider with get_fallthrough(_) -> Bool {
  false
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_meta(_, id) {
  match id {
    "hello.txt.gz" =>
      Some(
        StaticAssetMeta::new(
          asset_type="text/plain; charset=utf-8",
          etag="\"encoded-v1\"",
          mtime=1_709_251_199L,
          encoding="gzip",
          size=7L,
        ),
      )
    _ => None
  }
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_contents(_, id) {
  match id {
    "hello.txt.gz" => HttpResponse::new(OK).body(b"encoded")
    _ => HttpResponse::new(NotFound).body("Not Found")
  }
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_type(_, _ext) -> String? {
  None
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_encodings(_) -> Map[
  String,
  String,
] {
  { "gzip": ".gz" }
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_index_names(_) -> Array[
  String,
] {
  ["index.html"]
}

///|
impl ServeStaticProvider for EncodedStaticProvider with get_fallthrough(_) -> Bool {
  false
}

///|
fn localhost_url(port : Int, path : String) -> String {
  "http://127.0.0.1:\{port}\{path}"
}

///|
async fn wait_until_ready(port : Int) -> Unit {
  @async.retry(@async.FixedDelay(20), max_retry=50, () => {
    let (response, _body) = @http.get(localhost_url(port, "/__mocket_ready"))
    guard response.code == 200 else { raise ServerNotReady }
  })
}

///|
async fn with_test_server(app : Mocket, run_test : async (Int) -> Unit) -> Unit {
  let server = allocate_test_server()
  let port = server.addr.port()
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => app.serve_async_on(server))
    wait_until_ready(port)
    run_test(port)
  })
}

///|
async fn with_two_test_servers(
  app1 : Mocket,
  app2 : Mocket,
  run_test : async (Int, Int) -> Unit,
) -> Unit {
  let server1 = allocate_test_server()
  let server2 = allocate_test_server()
  let port1 = server1.addr.port()
  let port2 = server2.addr.port()
  app1.get("/__mocket_ready", _ => "ready")
  app2.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => app1.serve_async_on(server1))
    group.spawn_bg(no_wait=true, () => app2.serve_async_on(server2))
    wait_until_ready(port1)
    wait_until_ready(port2)
    run_test(port1, port2)
  })
}

///|
async fn issue_request(
  port : Int,
  meth : @http.RequestMethod,
  path : String,
  body? : Bytes,
  headers? : Map[String, String],
) -> (@http.Response, Bytes) {
  let client = @http.Client::new("http://127.0.0.1:\{port}")
  defer client.close()
  client.request(meth, path, extra_headers=headers.unwrap_or({}))
  match body {
    Some(body) => client.write(body)
    None => ()
  }
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
fn raw_header_value(raw_headers : String, header_name : String) -> String? {
  let needle = header_name.to_lower()
  for line in raw_headers.split("\r\n") {
    match line.find(":") {
      Some(index) => {
        let key = line[:index].to_string().to_lower()
        if key == needle {
          return Some(line[index + 1:].trim(chars=" ").to_string())
        }
      }
      None => ()
    }
  }
  None
}

///|
fn raw_header_count(raw_headers : String, header_name : String) -> Int {
  let needle = header_name.to_lower()
  let mut count = 0
  for line in raw_headers.split("\r\n") {
    match line.find(":") {
      Some(index) => {
        let key = line[:index].to_string().to_lower()
        if key == needle {
          count += 1
        }
      }
      None => ()
    }
  }
  count
}

///|
async test "serve_async strips query and reads put bodies" {
  let app = new()
  app.get("/hello/:name", event => {
    let name = event.params.get("name").unwrap_or("world")
    "Hello, \{name}!"
  })
  app.put("/echo/:name", event => {
    let name = event.params.get("name").unwrap_or("")
    let payload : String = event.req.body() catch { _ => "" }
    HttpResponse::new(OK).body("\{name}:\{payload}")
  })
  with_test_server(app, port => {
    let (response1, body1) = @http.get(
      localhost_url(port, "/hello/moonbit?lang=en"),
    )
    assert_eq(response1.code, 200)
    inspect(body1.text(), content="Hello, moonbit!")

    let (response2, body2) = @http.put(
      localhost_url(port, "/echo/native?kind=test"),
      "payload",
    )
    assert_eq(response2.code, 200)
    inspect(body2.text(), content="native:payload")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async preserves middleware onion order" {
  let log : Array[String] = []
  let app = new()
  app.use_middleware((event, next) => {
    if event.req.url != "/__mocket_ready" {
      log.push("before-1")
    }
    let responder = next()
    if event.req.url != "/__mocket_ready" {
      log.push("after-1")
    }
    responder
  })
  app.use_middleware((event, next) => {
    if event.req.url != "/__mocket_ready" {
      log.push("before-2")
    }
    let responder = next()
    if event.req.url != "/__mocket_ready" {
      log.push("after-2")
    }
    responder
  })
  app.get("/", _ => {
    log.push("handler")
    "ok"
  })
  with_test_server(app, port => {
    let (response, body) = @http.get(localhost_url(port, "/"))
    assert_eq(response.code, 200)
    inspect(body.text(), content="ok")
    inspect(log.join(","), content="before-1,before-2,handler,after-2,after-1")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async mounts static assets by prefix" {
  let app = new()
  app.static_assets("/assets", TestStaticProvider::{  })
  with_test_server(app, port => {
    let (response1, body1) = @http.get(localhost_url(port, "/assets/hello.txt"))
    assert_eq(response1.code, 200)
    assert_eq(
      response1.headers.get("content-type"),
      Some("text/plain; charset=utf-8"),
    )
    inspect(body1.text(), content="hi")

    let (response2, body2) = @http.get(localhost_url(port, "/assets"))
    assert_eq(response2.code, 200)
    inspect(body2.text(), content="index")

    let (response3, _body3) = @http.post(
      localhost_url(port, "/assets/hello.txt"),
      "",
    )
    assert_eq(response3.code, 405)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async preserves content-encoding for encoded static assets" {
  let app = new()
  app.static_assets("/assets", EncodedStaticProvider::{  })
  with_test_server(app, port => {
    let (get_response, get_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "Accept-Encoding": "gzip" },
    )
    assert_eq(get_response.code, 200)
    assert_eq(get_response.headers.get("content-encoding"), Some("gzip"))
    assert_eq(get_body, b"encoded")

    let (head_response, head_body) = issue_request(
      port,
      @http.Head,
      "/assets/hello.txt",
      headers={ "Accept-Encoding": "gzip" },
    )
    assert_eq(head_response.code, 200)
    assert_eq(head_response.headers.get("content-encoding"), Some("gzip"))
    assert_eq(head_response.headers.get("content-length"), Some("7"))
    assert_eq(head_body, b"")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async preserves vary and last-modified on conditional static responses" {
  let app = new()
  app.static_assets("/assets", EncodedStaticProvider::{  })
  with_test_server(app, port => {
    let (get_response, get_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "Accept-Encoding": "gzip" },
    )
    assert_eq(get_response.code, 200)
    assert_eq(get_body, b"encoded")
    assert_eq(get_response.headers.get("vary"), Some("Accept-Encoding"))
    let etag = get_response.headers.get("etag").unwrap_or("")
    let last_modified = get_response.headers.get("last-modified").unwrap_or("")
    guard etag != "" else {
      fail("expected encoded asset response to emit an ETag")
    }
    guard last_modified != "" else {
      fail("expected encoded asset response to emit Last-Modified")
    }

    let (etag_response, etag_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "Accept-Encoding": "gzip", "If-None-Match": etag },
    )
    assert_eq(etag_response.code, 304)
    assert_eq(etag_body, b"")
    assert_eq(etag_response.headers.get("vary"), Some("Accept-Encoding"))
    assert_eq(etag_response.headers.get("etag"), Some(etag))
    assert_eq(etag_response.headers.get("last-modified"), Some(last_modified))

    let (ims_response, ims_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "Accept-Encoding": "gzip", "If-Modified-Since": last_modified },
    )
    assert_eq(ims_response.code, 304)
    assert_eq(ims_body, b"")
    assert_eq(ims_response.headers.get("vary"), Some("Accept-Encoding"))
    assert_eq(ims_response.headers.get("etag"), Some(etag))
    assert_eq(ims_response.headers.get("last-modified"), Some(last_modified))

    let (precedence_response, precedence_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={
        "Accept-Encoding": "gzip",
        "If-None-Match": "\"miss\"",
        "If-Modified-Since": last_modified,
      },
    )
    assert_eq(precedence_response.code, 200)
    assert_eq(precedence_body, b"encoded")
    assert_eq(precedence_response.headers.get("vary"), Some("Accept-Encoding"))
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async writes cookie headers" {
  let app = new()
  app.get("/cookie", event => {
    event.res.set_cookie("session", "abc", path="/", http_only=true)
    "ok"
  })
  with_test_server(app, port => {
    let (response, body) = @http.get(localhost_url(port, "/cookie"))
    assert_eq(response.code, 200)
    inspect(body.text(), content="ok")
    inspect(
      response.headers.get("set-cookie").unwrap_or(""),
      content="session=abc; Path=/; HttpOnly",
    )
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async preserves explicit content-type headers without duplicates" {
  let app = new()
  app.get("/custom", event => {
    event.res.headers.set("content-type", "application/custom")
    "ok"
  })
  app.get("/override", event => {
    event.res.headers.set("content-type", "text/plain; charset=latin1")
    HttpResponse::new(OK, headers={ "Content-Type": "application/json" }).body(
      "{}",
    )
  })
  with_test_server(app, port => {
    let custom_headers = issue_raw_request_headers(
      port, "GET /custom HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
    )
    assert_true(custom_headers.has_prefix("HTTP/1.1 200 "))
    assert_eq(
      raw_header_value(custom_headers, "content-type"),
      Some("application/custom"),
    )
    assert_eq(raw_header_count(custom_headers, "content-type"), 1)

    let override_headers = issue_raw_request_headers(
      port, "GET /override HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
    )
    assert_true(override_headers.has_prefix("HTTP/1.1 200 "))
    assert_eq(
      raw_header_value(override_headers, "content-type"),
      Some("application/json"),
    )
    assert_eq(raw_header_count(override_headers, "content-type"), 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async handles head fallback, method not allowed, and options" {
  let app = new()
  app.get("/resource", event => {
    event.res.headers.set("X-Reply", "get")
    "payload"
  })
  app.get("/empty", _ => "")
  app.post("/resource", _ => HttpResponse::new(Created).body("created"))
  app.head("/override", event => {
    event.res.headers.set("X-Reply", "head")
    HttpResponse::new(OK).body("override")
  })
  app.get("/override", event => {
    event.res.headers.set("X-Reply", "get")
    HttpResponse::new(OK).body("get-body")
  })
  with_test_server(app, port => {
    let (head_response, head_body) = issue_request(
      port,
      @http.Head,
      "/resource",
    )
    assert_eq(head_response.code, 200)
    assert_eq(head_body, b"")
    inspect(head_response.headers.get("x-reply").unwrap_or(""), content="get")
    inspect(
      head_response.headers.get("content-length").unwrap_or(""),
      content="7",
    )

    let (override_response, override_body) = issue_request(
      port,
      @http.Head,
      "/override",
    )
    assert_eq(override_response.code, 200)
    assert_eq(override_body, b"")
    inspect(
      override_response.headers.get("x-reply").unwrap_or(""),
      content="head",
    )
    inspect(
      override_response.headers.get("content-length").unwrap_or(""),
      content="8",
    )

    let (empty_head_response, empty_head_body) = issue_request(
      port,
      @http.Head,
      "/empty",
    )
    assert_eq(empty_head_response.code, 200)
    assert_eq(empty_head_body, b"")
    inspect(
      empty_head_response.headers.get("content-length").unwrap_or(""),
      content="0",
    )

    let (method_response, method_body) = issue_request(
      port,
      @http.Put,
      "/resource",
    )
    assert_eq(method_response.code, 405)
    inspect(
      @utf8.decode(method_body) catch {
        _ => ""
      },
      content="Method Not Allowed",
    )
    inspect(
      method_response.headers.get("allow").unwrap_or(""),
      content="GET, HEAD, POST",
    )

    let (options_response, options_body) = issue_request(
      port,
      @http.Options,
      "/resource",
    )
    assert_eq(options_response.code, 204)
    assert_eq(options_body, b"")
    inspect(
      options_response.headers.get("allow").unwrap_or(""),
      content="GET, HEAD, POST, OPTIONS",
    )

    let (missing_response, missing_body) = issue_request(
      port,
      @http.Delete,
      "/missing",
    )
    assert_eq(missing_response.code, 404)
    inspect(@utf8.decode(missing_body) catch { _ => "" }, content="Not Found")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async does not overmatch non-terminal double wildcards" {
  let app = new()
  app.get("/files/**/meta", _ => "meta")
  app.post("/files/**/upload", _ => "upload")
  with_test_server(app, port => {
    let (meta_response, meta_body) = @http.get(
      localhost_url(port, "/files/a/b/meta"),
    )
    assert_eq(meta_response.code, 200)
    inspect(meta_body.text(), content="meta")

    let (missing_get_response, missing_get_body) = @http.get(
      localhost_url(port, "/files/a/b/raw"),
    )
    assert_eq(missing_get_response.code, 404)
    inspect(missing_get_body.text(), content="Not Found")

    let (short_get_response, short_get_body) = @http.get(
      localhost_url(port, "/files"),
    )
    assert_eq(short_get_response.code, 404)
    inspect(short_get_body.text(), content="Not Found")

    let (missing_put_response, missing_put_body) = issue_request(
      port,
      @http.Put,
      "/files/a/b/raw",
    )
    assert_eq(missing_put_response.code, 404)
    inspect(
      @utf8.decode(missing_put_body) catch {
        _ => ""
      },
      content="Not Found",
    )

    let (missing_options_response, missing_options_body) = issue_request(
      port,
      @http.Options,
      "/files/a/b/raw",
    )
    assert_eq(missing_options_response.code, 404)
    inspect(
      @utf8.decode(missing_options_body) catch {
        _ => ""
      },
      content="Not Found",
    )

    let (short_options_response, short_options_body) = issue_request(
      port,
      @http.Options,
      "/files",
    )
    assert_eq(short_options_response.code, 404)
    inspect(
      @utf8.decode(short_options_body) catch {
        _ => ""
      },
      content="Not Found",
    )
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async handles websocket text and binary messages" {
  let log : Array[String] = []
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, msg) =>
        match msg {
          Text(text) => peer.text("echo:\{text}")
          Binary(bytes) => peer.binary(bytes)
        }
      Close(_) => log.push("close")
    }
  })
  with_test_server(app, port => {
    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()

    client.send_text("moonbit")
    let text_reply = client.recv()
    inspect(text_reply.kind, content="Text")
    inspect(text_reply.read_all().text(), content="echo:moonbit")

    client.send_binary("bytes")
    let binary_reply = client.recv()
    inspect(binary_reply.kind, content="Binary")
    inspect(binary_reply.read_all().text(), content="bytes")

    client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard log.contains("open") && log.contains("close") else {
        raise ServerNotReady
      }
    })
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async honors mixed-case static and websocket upgrade headers" {
  let log : Array[String] = []
  let app = new()
  app.static_assets("/assets", EncodedStaticProvider::{  })
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server(app, port => {
    let encoded_headers = issue_raw_request_headers(
      port, "GET /assets/hello.txt HTTP/1.1\r\nHost: localhost\r\nAcCePt-EnCoDiNg: gzip\r\nConnection: close\r\n\r\n",
    )
    assert_true(encoded_headers.has_prefix("HTTP/1.1 200 "))
    assert_eq(
      raw_header_value(encoded_headers, "content-encoding"),
      Some("gzip"),
    )
    let last_modified = raw_header_value(encoded_headers, "last-modified").unwrap_or(
      "",
    )
    assert_eq(raw_header_value(encoded_headers, "etag"), Some("\"encoded-v1\""))
    assert_true(last_modified != "")

    let etag_headers = issue_raw_request_headers(
      port, "GET /assets/hello.txt HTTP/1.1\r\nHost: localhost\r\nAcCePt-EnCoDiNg: gzip\r\nIf-NoNe-MaTcH: \"encoded-v1\"\r\nConnection: close\r\n\r\n",
    )
    assert_true(etag_headers.has_prefix("HTTP/1.1 304 "))
    assert_eq(raw_header_value(etag_headers, "etag"), Some("\"encoded-v1\""))

    let ims_headers = issue_raw_request_headers(
      port,
      "GET /assets/hello.txt HTTP/1.1\r\nHost: localhost\r\nAcCePt-EnCoDiNg: gzip\r\nIf-MoDiFiEd-SiNcE: \{last_modified}\r\nConnection: close\r\n\r\n",
    )
    assert_true(ims_headers.has_prefix("HTTP/1.1 304 "))
    assert_eq(
      raw_header_value(ims_headers, "last-modified"),
      Some(last_modified),
    )

    let upgrade_headers = issue_raw_request_headers(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nCoNnEcTiOn: Upgrade\r\nUpGrAdE: websocket\r\nSeC-WeBsOcKeT-KeY: dGhlIHNhbXBsZSBub25jZQ==\r\nSeC-WeBsOcKeT-VeRsIoN: 13\r\n\r\n",
    )
    assert_true(upgrade_headers.has_prefix("HTTP/1.1 101 "))
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard log.contains("open") && log.contains("close") else {
        raise ServerNotReady
      }
    })
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async matches grouped and dynamic websocket routes" {
  let app = new()
  app.group("/api", group => {
    group.ws("/room/:name", event => {
      match event {
        Message(peer, Text(text)) => peer.text("group:\{text}")
        _ => ()
      }
    })
  })
  with_test_server(app, port => {
    let client = @websocket.connect("ws://127.0.0.1:\{port}/api/room/alpha")
    defer client.close()

    client.send_text("joined")
    let reply = client.recv()
    inspect(reply.kind, content="Text")
    inspect(reply.read_all().text(), content="group:joined")
    client.send_close()
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps websocket subscriptions across events" {
  let app = new()
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("leave")) => peer.unsubscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      _ => ()
    }
  })
  with_test_server(app, port => {
    let client1 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client2.close()

    client1.send_text("publish")
    inspect(client1.recv().read_all().text(), content="fanout")
    inspect(client2.recv().read_all().text(), content="fanout")

    client1.send_text("leave")
    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")
    inspect(
      @async.with_timeout_opt(100, () => client1.recv().read_all().text()),
      content="None",
    )

    client1.send_close()
    client2.send_close()
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async isolates websocket channels per app" {
  let app1 = new()
  let app2 = new()
  app1.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "alpha")
      _ => ()
    }
  })
  app2.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "beta")
      _ => ()
    }
  })
  with_two_test_servers(app1, app2, (port1, port2) => {
    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    client1.send_text("publish")
    inspect(client1.recv().read_all().text(), content="alpha")
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="beta")
    inspect(
      @async.with_timeout_opt(100, () => client1.recv().read_all().text()),
      content="None",
    )

    client1.send_close()
    client2.send_close()
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}
