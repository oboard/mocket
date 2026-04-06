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
  @async.retry(@async.FixedDelay(20), max_retry=50, () => {
    let (response, _body) = @http.get(localhost_url(port, "/__mocket_ready"))
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
  app.get("/__mocket_ready", _ => "ready")
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
async test "static_file provider exposes file metadata" {
  let provider = StaticFileProvider::new(path="static_file/testdata")
  match provider.get_meta("hello.txt") {
    Some(meta) => {
      assert_eq(meta.size, Some(16L))
      assert_eq(meta.path, Some("static_file/testdata/hello.txt"))
      guard meta.etag is Some(_) else {
        fail("expected filesystem provider to emit an ETag")
      }
    }
    None => fail("expected filesystem provider metadata")
  }
}

///|
async test "static_file serves files and directory index" {
  let app = @crescent.Mocket::new()
  app.static_assets(
    "/assets",
    StaticFileProvider::new(path="static_file/testdata"),
  )
  with_test_server(app, port => {
    let (file_response, file_body) = @http.get(
      localhost_url(port, "/assets/hello.txt"),
    )
    assert_eq(file_response.code, 200)
    assert_eq(
      file_body.binary(),
      @fs.read_file("static_file/testdata/hello.txt").binary(),
    )

    let (index_response, index_body) = @http.get(localhost_url(port, "/assets"))
    assert_eq(index_response.code, 200)
    assert_eq(
      index_body.binary(),
      @fs.read_file("static_file/testdata/index.html").binary(),
    )
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "static_file serves head and validates etags" {
  let app = @crescent.Mocket::new()
  app.static_assets(
    "/assets",
    StaticFileProvider::new(path="static_file/testdata"),
  )
  with_test_server(app, port => {
    let (get_response, get_body) = @http.get(
      localhost_url(port, "/assets/hello.txt"),
    )
    assert_eq(get_response.code, 200)
    assert_eq(
      get_body.binary(),
      @fs.read_file("static_file/testdata/hello.txt").binary(),
    )
    let etag = get_response.headers.get("etag").unwrap_or("")
    guard etag != "" else {
      fail("expected filesystem provider to emit an ETag")
    }
    let last_modified = get_response.headers.get("last-modified").unwrap_or("")
    guard last_modified != "" else {
      fail("expected filesystem provider to emit Last-Modified")
    }

    let (head_response, head_body) = issue_request(
      port,
      @http.Head,
      "/assets/hello.txt",
    )
    assert_eq(head_response.code, 200)
    assert_eq(head_body, b"")
    assert_eq(head_response.headers.get("etag"), Some(etag))
    assert_eq(head_response.headers.get("last-modified"), Some(last_modified))
    assert_eq(head_response.headers.get("content-length"), Some("16"))

    let (cached_response, cached_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "If-None-Match": etag },
    )
    assert_eq(cached_response.code, 304)
    assert_eq(cached_body, b"")
    assert_eq(cached_response.headers.get("etag"), Some(etag))
    assert_eq(cached_response.headers.get("last-modified"), Some(last_modified))

    let weak_etag = "W/\{etag}"
    let (weak_response, weak_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "If-None-Match": weak_etag },
    )
    assert_eq(weak_response.code, 304)
    assert_eq(weak_body, b"")

    let (multi_response, multi_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "If-None-Match": "\"miss\", \{etag}" },
    )
    assert_eq(multi_response.code, 304)
    assert_eq(multi_body, b"")

    let (ims_response, ims_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "If-Modified-Since": last_modified },
    )
    assert_eq(ims_response.code, 304)
    assert_eq(ims_body, b"")
    assert_eq(ims_response.headers.get("etag"), Some(etag))
    assert_eq(ims_response.headers.get("last-modified"), Some(last_modified))

    let (stale_response, stale_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={ "If-Modified-Since": "Thu, 01 Jan 1970 00:00:00 GMT" },
    )
    assert_eq(stale_response.code, 200)
    assert_eq(
      stale_body,
      @fs.read_file("static_file/testdata/hello.txt").binary(),
    )

    let (precedence_response, precedence_body) = issue_request(
      port,
      @http.Get,
      "/assets/hello.txt",
      headers={
        "If-None-Match": "\"miss\"",
        "If-Modified-Since": last_modified,
      },
    )
    assert_eq(precedence_response.code, 200)
    assert_eq(
      precedence_body,
      @fs.read_file("static_file/testdata/hello.txt").binary(),
    )
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "static_file respects grouped mounts and blocks traversal" {
  let app = @crescent.Mocket::new()
  app.group("/api", group => {
    group.static_assets(
      "/assets",
      StaticFileProvider::new(path="static_file/testdata"),
    )
  })
  with_test_server(app, port => {
    let (file_response, file_body) = @http.get(
      localhost_url(port, "/api/assets/hello.txt"),
    )
    assert_eq(file_response.code, 200)
    assert_eq(
      file_body.binary(),
      @fs.read_file("static_file/testdata/hello.txt").binary(),
    )

    let (missing_response, missing_body) = @http.get(
      localhost_url(port, "/api/assets/missing.txt"),
    )
    assert_eq(missing_response.code, 404)
    assert_eq(missing_body.text().trim(chars="\r\n"), "Not Found")

    let (traversal_response, traversal_body) = @http.get(
      localhost_url(port, "/api/assets/../README.md"),
    )
    assert_eq(traversal_response.code, 404)
    assert_eq(traversal_body.text().trim(chars="\r\n"), "Not Found")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}
