///|
async test "fetch uses async client for request headers and payloads" {
  let app = Mocket::new()
  app.get("/", _ => "root")
  app.get("/fetch/hello", event => {
    let who = event.req.headers.get("x-name").unwrap_or("world").to_string()
    event.res.headers.set("X-Reply", "native")
    HttpResponse::new(OK).body("hello:\{who}")
  })
  app.post("/fetch/echo", event => {
    let payload : String = event.req.body() catch { _ => "" }
    event.res.headers.set("X-Body-Len", payload.length().to_string())
    HttpResponse::new(Created).body("post:\{payload}")
  })
  app.patch("/fetch/bin", event => {
    event.res.headers.set("X-Body-Len", event.req.raw_body.length().to_string())
    event.req.raw_body
  })
  with_test_server(app, port => {
    let response1 = fetch(localhost_url(port, "/fetch/hello?via=async"), Get, headers={
      "X-Name": "moon",
    })
    assert_eq(response1.status_code, OK)
    let body1 : String = response1.read_body()
    inspect(body1, content="hello:moon")
    inspect(response1.headers.get("x-reply").unwrap_or(""), content="native")

    let response2 = fetch(
      localhost_url(port, "/fetch/echo"),
      Post,
      body="payload",
      headers={ "X-Test": "yes" },
    )
    assert_eq(response2.status_code, Created)
    let body2 : String = response2.read_body()
    inspect(body2, content="post:payload")
    inspect(response2.headers.get("x-body-len").unwrap_or(""), content="7")

    let response3 = fetch(
      localhost_url(port, "/fetch/bin"),
      Patch,
      data=b"\x00\x01\x02",
    )
    assert_eq(response3.status_code, OK)
    assert_eq(response3.raw_body, b"\x00\x01\x02")
    inspect(response3.headers.get("x-body-len").unwrap_or(""), content="3")

    let response4 = fetch("http://127.0.0.1:\{port}?via=query", Get)
    assert_eq(response4.status_code, OK)
    let body4 : String = response4.read_body()
    inspect(body4, content="root")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "fetch preserves explicit content-type without duplicate request headers" {
  let raw_headers = Ref::new("")
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      raw_headers.val = conn.read_until("\r\n\r\n").unwrap_or("")
      conn.write(
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
      )
    })

    let response = fetch(
      "http://127.0.0.1:\{port}/request",
      Post,
      data=text("body"),
      headers={ "content-type": "application/custom", "X-Test": "yes" },
    )
    assert_eq(response.status_code, OK)
    assert_eq(response.raw_body, b"")
  })

  assert_eq(
    raw_header_value(raw_headers.val, "content-type"),
    Some("application/custom"),
  )
  assert_eq(raw_header_count(raw_headers.val, "content-type"), 1)
  assert_eq(raw_header_value(raw_headers.val, "x-test"), Some("yes"))
}

///|
async test "fetch supports head and rejects unsupported protocols" {
  let app = Mocket::new()
  app.head("/fetch/head", event => {
    event.res.headers.set("X-Reply", "head")
    HttpResponse::new(NoContent).body("ignored")
  })
  with_test_server(app, port => {
    let response = fetch(localhost_url(port, "/fetch/head"), Head)
    assert_eq(response.status_code, NoContent)
    let body : String = response.read_body()
    inspect(body, content="")
    inspect(response.headers.get("x-reply").unwrap_or(""), content="head")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }

  let unsupported = try? fetch("ftp://example.com/data", Get)
  match unsupported {
    Err(FetchError::RequestFailed(message)) =>
      inspect(message, content="unsupported protocol: ftp")
    Err(err) => fail("unexpected error: \{err}")
    Ok(_) => fail("expected fetch to reject unsupported protocol")
  }
}
