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
async fn with_test_server_options(
  app : Mocket,
  options : NativeServeOptions,
  run_test : async (Int) -> Unit,
) -> Unit {
  let server = allocate_test_server()
  let port = server.addr.port()
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => app.serve_async_on_with(server, options))
    wait_until_ready(port)
    run_test(port)
  })
}

///|
async fn with_port_bound_test_server(
  app : Mocket,
  run_test : async (Int) -> Unit,
) -> Unit {
  app.get("/__mocket_ready", _ => "ready")
  let start_offset = @async.now().to_int() % 20_000
  for attempt = 0; attempt < 2_048; attempt = attempt + 1 {
    let port = 40_000 + (start_offset + attempt) % 20_000
    let attempt_result : Result[Bool, Error] = try? @async.with_task_group(group => {
      let task = group.spawn(no_wait=true, allow_failure=true, () => {
        app.serve_async(port~)
      })
      match @async.with_timeout_opt(50, () => try? task.wait()) {
        Some(Ok(_)) => {
          task.cancel()
          ignore(try? task.wait())
          raise ServerNotReady
        }
        Some(Err(@os_error.OSError(errno, ..))) if errno == 1 => {
          task.cancel()
          ignore(try? task.wait())
          raise SocketBindUnavailable
        }
        Some(Err(@os_error.OSError(_) as err)) if err.is_EACCES() => {
          task.cancel()
          ignore(try? task.wait())
          raise SocketBindUnavailable
        }
        Some(Err(@os_error.OSError(errno, ..))) if errno == 48 ||
          errno == 98 ||
          errno == 10048 => {
          task.cancel()
          ignore(try? task.wait())
          false
        }
        Some(Err(err)) => {
          task.cancel()
          ignore(try? task.wait())
          raise err
        }
        None => {
          wait_until_ready(port)
          run_test(port)
          task.cancel()
          ignore(try? task.wait())
          true
        }
      }
    })
    match attempt_result {
      Ok(true) => return
      Ok(false) => ()
      Err(err) => raise err
    }
  }
  raise SocketBindUnavailable
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
async fn issue_raw_request_response(
  port : Int,
  request : String,
) -> (String, String) {
  let addr = @socket.Addr::parse("127.0.0.1:\{port}") catch {
    _ => fail("invalid raw request address")
  }
  let client = @socket.Tcp::connect(addr)
  defer client.close()
  client.write(request)
  read_raw_http_response(client)
}

///|
async fn read_raw_http_response(client : @socket.Tcp) -> (String, String) {
  let headers = client.read_until("\r\n\r\n").unwrap_or("")
  let body = if raw_header_value(headers, "Transfer-Encoding")
    .unwrap_or("")
    .to_lower()
    .contains("chunked") {
    read_chunked_http_body(client)
  } else {
    match raw_header_value(headers, "Content-Length") {
      Some(length_text) => {
        let length = @string.parse_int(length_text) catch { _ => 0 }
        if length == 0 {
          ""
        } else {
          @utf8.decode(client.read_exactly(length)) catch {
            _ => ""
          }
        }
      }
      None => @utf8.decode(client.read_all().binary()) catch { _ => "" }
    }
  }
  (headers, body)
}

///|
fn repeated_ascii_text(piece : String, count : Int) -> String {
  let buffer = @buffer.new()
  for _ in 0..<count {
    buffer.write_string_utf8(piece)
  }
  @utf8.decode(buffer.contents()) catch {
    _ => ""
  }
}

///|
async fn read_chunked_http_body(client : @socket.Tcp) -> String {
  let buffer = @buffer.new()
  for ;; {
    let chunk_len_line = client.read_until("\r\n").unwrap_or("")
    guard chunk_len_line != "" else {
      fail("unexpected EOF while reading chunked response size")
    }
    let chunk_len_text = match chunk_len_line.find(";") {
      Some(index) => chunk_len_line[:index].to_string()
      None => chunk_len_line
    }
    let chunk_len = @string.parse_int(
      chunk_len_text.trim(chars="\r\n"),
      base=16,
    ) catch {
      _ => fail("invalid chunked response size: \{chunk_len_text}")
    }
    if chunk_len == 0 {
      guard client.read_exactly(2) == "\r\n" else {
        fail("invalid chunked response terminator")
      }
      return @utf8.decode(buffer.contents()) catch {
        _ => fail("chunked response body is not valid UTF-8")
      }
    }
    buffer.write_bytes(client.read_exactly(chunk_len))
    guard client.read_exactly(2) == "\r\n" else {
      fail("invalid chunked response chunk terminator")
    }
  }
}

///|
fn websocket_close_code_from_wire(code : UInt) -> @websocket.CloseCode {
  match code {
    1000 => @websocket.CloseCode::Normal
    1001 => @websocket.CloseCode::GoingAway
    1002 => @websocket.CloseCode::ProtocolError
    1003 => @websocket.CloseCode::UnsupportedData
    1006 => @websocket.CloseCode::Abnormal
    1007 => @websocket.CloseCode::InvalidFramePayload
    1008 => @websocket.CloseCode::PolicyViolation
    1009 => @websocket.CloseCode::MessageTooBig
    1010 => @websocket.CloseCode::MissingExtension
    1011 => @websocket.CloseCode::InternalError
    _ => @websocket.CloseCode::Other(code.to_uint16())
  }
}

///|
async fn read_raw_websocket_close_frame(
  client : @http.Client,
) -> (@websocket.CloseCode, String?) {
  let (opcode, payload) = read_raw_websocket_frame(client)
  assert_eq(opcode, 0x08)
  if payload is [u16be(code), .. reason] {
    let reason = @utf8.decode(reason) catch {
      _ => fail("websocket close reason was not valid UTF-8")
    }
    let reason = if reason == "" { None } else { Some(reason) }
    (websocket_close_code_from_wire(code), reason)
  } else {
    (@websocket.CloseCode::Normal, None)
  }
}

///|
async fn read_raw_websocket_frame_opt(
  client : @http.Client,
  timeout_ms : Int,
) -> (Int, Bytes)? {
  let header = match
    @async.with_timeout_opt(timeout_ms, () => client.read_exactly(2)) {
    Some(header) => header
    None => return None
  }
  let opcode = header[0].to_int() & 0x0f
  let payload_len = header[1].to_int() & 0x7f
  guard payload_len < 126 else {
    fail("unexpected extended websocket frame length: \{payload_len}")
  }
  let payload = if payload_len == 0 {
    b""
  } else {
    match
      @async.with_timeout_opt(timeout_ms, () => client.read_exactly(payload_len)) {
      Some(payload) => payload
      None => fail("timed out waiting for websocket frame payload")
    }
  }
  Some((opcode, payload))
}

///|
async fn read_raw_websocket_frame(client : @http.Client) -> (Int, Bytes) {
  match read_raw_websocket_frame_opt(client, 200) {
    Some(frame) => frame
    None => fail("timed out waiting for websocket frame header")
  }
}

///|
async fn issue_raw_websocket_close(
  port : Int,
  path : String,
  frames : Array[Bytes],
) -> (@websocket.CloseCode, String?) {
  let http_client = @http.Client::new("http://127.0.0.1:\{port}")
  defer http_client.close()
  ignore(@websocket.from_http_client(http_client, path))
  for frame in frames {
    ignore(try? http_client.write(frame))
    ignore(try? http_client.flush())
  }
  read_raw_websocket_close_frame(http_client)
}

///|
fn uint16_be_bytes(value : UInt16) -> Bytes {
  let result = FixedArray::make(2, b'\x00')
  result.unsafe_write_uint16_be(0, value)
  result.unsafe_reinterpret_as_bytes()
}

///|
fn raw_websocket_close_frame(code : UInt16, reason : Bytes) -> Bytes {
  let payload_len = 2 + reason.length()
  Bytes::from_array(
    [
      b'\x88',
      payload_len.to_byte(),
      ..uint16_be_bytes(code).to_array(),
      ..reason.to_array(),
    ],
  )
}

///|
fn raw_websocket_small_frame(first_byte : Byte, payload : Bytes) -> Bytes {
  Bytes::from_array(
    [first_byte, payload.length().to_byte(), ..payload.to_array()],
  )
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
    event.res.headers.set("X-Raw-Url", event.req.url)
    event.res.headers.set("X-Path", event.req.path())
    event.res.headers.set("X-Lang", event.req.get_query("lang").unwrap_or(""))
    "Hello, \{name}!"
  })
  app.put("/echo/:name", event => {
    let name = event.params.get("name").unwrap_or("")
    let payload : String = event.req.body() catch { _ => "" }
    event.res.headers.set("X-Kind", event.req.get_query("kind").unwrap_or(""))
    HttpResponse::new(OK).body("\{name}:\{payload}")
  })
  with_test_server(app, port => {
    let (response1, body1) = @http.get(
      localhost_url(port, "/hello/moonbit?lang=en"),
    )
    assert_eq(response1.code, 200)
    inspect(body1.text(), content="Hello, moonbit!")
    inspect(
      response1.headers.get("x-raw-url").unwrap_or(""),
      content="/hello/moonbit?lang=en",
    )
    inspect(
      response1.headers.get("x-path").unwrap_or(""),
      content="/hello/moonbit",
    )
    inspect(response1.headers.get("x-lang").unwrap_or(""), content="en")

    let (response2, body2) = @http.put(
      localhost_url(port, "/echo/native?kind=test"),
      "payload",
    )
    assert_eq(response2.code, 200)
    inspect(body2.text(), content="native:payload")
    inspect(response2.headers.get("x-kind").unwrap_or(""), content="test")
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
async test "serve_async keeps invalid websocket opcodes connection-local and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let http_client = @http.Client::new("http://127.0.0.1:\{port}")
    defer http_client.close()
    let ws_client = @websocket.from_http_client(http_client, "/ws")
    defer ws_client.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        http_client.write(Bytes::from_array([b'\x8b', b'\x00']))
      })
      match
        @async.with_timeout_opt(200, () => {
          try? ws_client.recv().read_all().binary()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::ProtocolError,
              Some(reason)
            )
          )
        ) => inspect(reason, content="Invalid OP code 11")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected invalid websocket opcode close, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected invalid websocket opcode close, got error: \{err}")
        Some(Ok(bytes)) =>
          fail(
            "expected invalid websocket opcode close, got \{bytes.length()} bytes",
          )
        None => fail("timed out waiting for invalid websocket opcode close")
      }
    })
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps invalid websocket text payloads connection-local and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()
    client
    ..start_message(Text)
    ..write(Bytes::from_array([b'\x80']))
    .end_message()
    match
      @async.with_timeout_opt(200, () => try? client.recv().read_all().binary()) {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::InvalidFramePayload,
            Some(reason)
          )
        )
      ) => inspect(reason, content="Text message is not valid UTF8")
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected invalid websocket text payload close, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail("expected invalid websocket text payload close, got error: \{err}")
      Some(Ok(bytes)) =>
        fail(
          "expected invalid websocket text payload close, got \{bytes.length()} bytes",
        )
      None => fail("timed out waiting for invalid websocket text payload close")
    }
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps websocket protocol edge failures connection-local and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    async fn expect_bad_ws_frame(
      frame : Bytes,
      expected_code : @websocket.CloseCode,
      expected_reason : String,
    ) -> Unit {
      let http_client = @http.Client::new("http://127.0.0.1:\{port}")
      defer http_client.close()
      let ws_client = @websocket.from_http_client(http_client, "/ws")
      defer ws_client.close()
      @async.with_task_group(group => {
        group.spawn_bg(() => http_client.write(frame))
        match
          @async.with_timeout_opt(200, () => {
            try? ws_client.recv().read_all().binary()
          }) {
          Some(Err(@websocket.ConnectionClosed(code, Some(reason)))) => {
            assert_eq(code, expected_code)
            inspect(reason, content=expected_reason)
          }
          Some(Err(@websocket.ConnectionClosed(code, reason))) =>
            fail(
              "expected \{expected_code} / \{expected_reason}, got \{code} / \{reason}",
            )
          Some(Err(err)) =>
            fail("expected websocket protocol close, got error: \{err}")
          Some(Ok(bytes)) =>
            fail(
              "expected websocket protocol close, got \{bytes.length()} bytes",
            )
          None => fail("timed out waiting for websocket protocol close")
        }
      })
    }

    expect_bad_ws_frame(
      Bytes::from_array([b'\xc1', b'\x00']),
      @websocket.CloseCode::MissingExtension,
      "Reserved bits are not zero",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    expect_bad_ws_frame(
      Bytes::from_array([b'\x09', b'\x00']),
      @websocket.CloseCode::ProtocolError,
      "Control frames must not be fragmented",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 3 && closed.val == 3 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps websocket sequencing and control-size failures connection-local and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let too_long_control_len : UInt16 = 128
    fn u16_to_bytes(len : UInt16) -> Bytes {
      let result = FixedArray::make(2, b'\x00')
      result.unsafe_write_uint16_be(0, len)
      result.unsafe_reinterpret_as_bytes()
    }

    async fn expect_bad_ws_frames(
      frames : Array[Bytes],
      expected_code : @websocket.CloseCode,
      expected_reason : String,
    ) -> Unit {
      let (code, reason) = issue_raw_websocket_close(port, "/ws", frames)
      assert_eq(code, expected_code)
      inspect(reason.unwrap_or(""), content=expected_reason)
    }

    expect_bad_ws_frames(
      [
        Bytes::from_array([b'\x01', b'\x00']),
        Bytes::from_array([b'\x81', b'\x00']),
      ],
      @websocket.CloseCode::ProtocolError,
      "New message within a fragmented message",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    expect_bad_ws_frames(
      [
        Bytes::from_array(
          [b'\x89', 126, ..u16_to_bytes(too_long_control_len).to_array()],
        ),
      ],
      @websocket.CloseCode::MessageTooBig,
      "Control frame too long",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 3 && closed.val == 3 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps websocket continuation and length-format failures connection-local and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    async fn expect_bad_ws_frames(
      frames : Array[Bytes],
      expected_code : @websocket.CloseCode,
      expected_reason : String,
    ) -> Unit {
      let (code, reason) = issue_raw_websocket_close(port, "/ws", frames)
      assert_eq(code, expected_code)
      inspect(reason.unwrap_or(""), content=expected_reason)
    }

    expect_bad_ws_frames(
      [Bytes::from_array([b'\x80', b'\x00'])],
      @websocket.CloseCode::ProtocolError,
      "Unexpected continuation frame",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    expect_bad_ws_frames(
      [Bytes::from_array([b'\x81', 126, b'\x00', b'\x7d'])],
      @websocket.CloseCode::ProtocolError,
      "Invalid payload length format",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })

    expect_bad_ws_frames(
      [
        Bytes::from_array([
          b'\x81', 127, b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
          b'\xff',
        ]),
      ],
      @websocket.CloseCode::ProtocolError,
      "Invalid payload length format",
    )
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 3 && closed.val == 3 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 4 && closed.val == 4 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async echoes websocket close reasons and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let (code, reason) = issue_raw_websocket_close(port, "/ws", [
      raw_websocket_close_frame(1000, b"bye"),
    ])
    assert_eq(code, @websocket.CloseCode::Normal)
    inspect(reason.unwrap_or(""), content="bye")
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async rejects invalid websocket close reasons and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let (code, reason) = issue_raw_websocket_close(port, "/ws", [
      raw_websocket_close_frame(1000, Bytes::from_array([b'\x80'])),
    ])
    assert_eq(code, @websocket.CloseCode::InvalidFramePayload)
    inspect(reason.unwrap_or(""), content="Invalid UTF8 in close reason")
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async auto-replies to websocket ping frames without leaking control messages" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let http_client = @http.Client::new("http://127.0.0.1:\{port}")
    defer http_client.close()
    let ws_client = @websocket.from_http_client(http_client, "/ws")
    defer ws_client.close()

    let ping_payload = b"pong"
    http_client.write(
      Bytes::from_array([b'\x89', 0x04, ..ping_payload.to_array()]),
    )
    let (opcode, payload) = read_raw_websocket_frame(http_client)
    assert_eq(opcode, 0x0a)
    inspect(
      @utf8.decode(payload) catch {
        _ => fail("websocket pong payload was not valid UTF-8")
      },
      content="pong",
    )
    assert_eq(messages.val, 0)

    ws_client.send_text("ok")
    inspect(ws_client.recv().read_all().text(), content="ok")
    ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async ignores unsolicited websocket pong frames without leaking control messages" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let http_client = @http.Client::new("http://127.0.0.1:\{port}")
    defer http_client.close()
    let ws_client = @websocket.from_http_client(http_client, "/ws")
    defer ws_client.close()

    http_client.write(Bytes::from_array([b'\x8a', 0x04, ..b"noop".to_array()]))
    match read_raw_websocket_frame_opt(http_client, 100) {
      None => ()
      Some((opcode, payload)) =>
        fail(
          "expected no wire response to unsolicited pong, got opcode \{opcode} with \{payload.length()} bytes",
        )
    }
    assert_eq(messages.val, 0)

    ws_client.send_text("ok")
    inspect(ws_client.recv().read_all().text(), content="ok")
    ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async routes fragmented websocket messages while replying to in-flight pings" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let http_client = @http.Client::new("http://127.0.0.1:\{port}")
    defer http_client.close()
    ignore(@websocket.from_http_client(http_client, "/ws"))

    http_client.write(raw_websocket_small_frame(b'\x01', b"a"))
    http_client.write(raw_websocket_small_frame(b'\x89', b"mid!"))
    http_client.write(raw_websocket_small_frame(b'\x80', b"b"))

    let (pong_opcode, pong_payload) = read_raw_websocket_frame(http_client)
    assert_eq(pong_opcode, 0x0a)
    inspect(
      @utf8.decode(pong_payload) catch {
        _ => fail("websocket pong payload was not valid UTF-8")
      },
      content="mid!",
    )

    let (text_opcode, text_payload) = read_raw_websocket_frame(http_client)
    assert_eq(text_opcode, 0x01)
    inspect(
      @utf8.decode(text_payload) catch {
        _ => fail("websocket text payload was not valid UTF-8")
      },
      content="ab",
    )
    assert_eq(messages.val, 1)

    http_client.write(raw_websocket_close_frame(1000, b""))
    let (close_code, close_reason) = read_raw_websocket_close_frame(http_client)
    assert_eq(close_code, @websocket.CloseCode::Normal)
    inspect(close_reason.unwrap_or(""), content="")
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("ok")
    inspect(healthy_ws_client.recv().read_all().text(), content="ok")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 2)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async replies to multiple websocket pings in order without leaking control messages" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let messages : Ref[Int] = Ref::new(0)
  let healthy_hits : Ref[Int] = Ref::new(0)
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => {
        messages.val += 1
        peer.text(text)
      }
      Message(peer, Binary(bytes)) => {
        messages.val += 1
        peer.binary(bytes)
      }
      Close(_) => closed.val += 1
    }
  })
  app.get("/healthy", _ => {
    healthy_hits.val += 1
    "ok"
  })
  with_test_server(app, port => {
    let http_client = @http.Client::new("http://127.0.0.1:\{port}")
    defer http_client.close()
    ignore(@websocket.from_http_client(http_client, "/ws"))

    http_client.write(raw_websocket_small_frame(b'\x89', b"p1"))
    http_client.write(raw_websocket_small_frame(b'\x89', b"p2"))

    let (first_opcode, first_payload) = read_raw_websocket_frame(http_client)
    assert_eq(first_opcode, 0x0a)
    inspect(
      @utf8.decode(first_payload) catch {
        _ => fail("first websocket pong payload was not valid UTF-8")
      },
      content="p1",
    )

    let (second_opcode, second_payload) = read_raw_websocket_frame(http_client)
    assert_eq(second_opcode, 0x0a)
    inspect(
      @utf8.decode(second_payload) catch {
        _ => fail("second websocket pong payload was not valid UTF-8")
      },
      content="p2",
    )
    assert_eq(messages.val, 0)

    http_client.write(raw_websocket_small_frame(b'\x81', b"ok"))
    let (text_opcode, text_payload) = read_raw_websocket_frame(http_client)
    assert_eq(text_opcode, 0x01)
    inspect(
      @utf8.decode(text_payload) catch {
        _ => fail("websocket text payload was not valid UTF-8")
      },
      content="ok",
    )

    http_client.write(raw_websocket_close_frame(1000, b""))
    let (close_code, close_reason) = read_raw_websocket_close_frame(http_client)
    assert_eq(close_code, @websocket.CloseCode::Normal)
    inspect(close_reason.unwrap_or(""), content="")
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 1)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
    assert_eq(healthy_hits.val, 1)

    let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer healthy_ws_client.close()
    healthy_ws_client.send_text("fresh")
    inspect(healthy_ws_client.recv().read_all().text(), content="fresh")
    healthy_ws_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 2 && closed.val == 2 else { raise ServerNotReady }
    })
    assert_eq(messages.val, 2)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with enforces max_connections" {
  let app = new()
  let gate = @async.Queue::new(kind=Unbounded)
  let started : Ref[Int] = Ref::new(0)
  app.get("/serial", _ => {
    started.val += 1
    ignore(try? gate.get())
    "ok"
  })
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_connections=1),
      )
    })
    wait_until_ready(port)

    let first = group.spawn(no_wait=true, () => {
      try? @http.get(localhost_url(port, "/serial"))
    })
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard started.val == 1 else { raise ServerNotReady }
    })

    let second = group.spawn(no_wait=true, () => {
      try? @http.get(localhost_url(port, "/serial"))
    })
    match @async.with_timeout_opt(100, () => second.wait()) {
      None => ()
      Some(_) =>
        fail(
          "expected second request to remain blocked while max_connections=1",
        )
    }
    assert_eq(started.val, 1)

    gate.put(())
    match first.wait() {
      Ok((first_response, first_body)) => {
        assert_eq(first_response.code, 200)
        inspect(first_body.text(), content="ok")
      }
      Err(err) => fail("first limited request failed: \{err}")
    }

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard started.val == 2 else { raise ServerNotReady }
    })
    match @async.with_timeout_opt(100, () => second.wait()) {
      None => ()
      Some(_) =>
        fail(
          "expected second request to stay blocked until the first handler releases it",
        )
    }

    gate.put(())
    match second.wait() {
      Ok((second_response, second_body)) => {
        assert_eq(second_response.code, 200)
        inspect(second_body.text(), content="ok")
      }
      Err(err) => fail("second limited request failed: \{err}")
    }
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with rejects non-positive max_connections" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(max_connections=0),
  )
  match result {
    Err(NativeServeError::InvalidMaxConnections(0)) => ()
    Err(err) => fail("unexpected invalid max_connections error: \{err}")
    Ok(_) => fail("expected serve_async_on_with to reject max_connections=0")
  }
}

///|
async test "serve_async_with rejects non-positive max_connections" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(max_connections=0),
  )
  match result {
    Err(NativeServeError::InvalidMaxConnections(0)) => ()
    Err(err) => fail("unexpected invalid max_connections error: \{err}")
    Ok(_) => fail("expected serve_async_with to reject max_connections=0")
  }
}

///|
async test "serve_async_on_with enforces max_request_body_bytes for fixed-length bodies" {
  let app = new()
  let handled : Ref[Int] = Ref::new(0)
  app.post("/body", event => {
    handled.val += 1
    event.req.raw_body
  })
  app.get("/healthy", _ => "ok")
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_request_body_bytes=4),
      )
    })
    wait_until_ready(port)

    let (ok_response, ok_body) = @http.post(
      localhost_url(port, "/body"),
      "moon",
      headers={ "Connection": "close" },
    )
    assert_eq(ok_response.code, 200)
    inspect(ok_body.text(), content="moon")
    assert_eq(handled.val, 1)

    let (rejected_response, rejected_body) = @http.post(
      localhost_url(port, "/body"),
      "moonbit",
      headers={ "Connection": "close" },
    )
    assert_eq(rejected_response.code, 413)
    assert_eq(rejected_response.headers.get("connection"), Some("close"))
    inspect(
      rejected_body.text().trim(chars="\r\n"),
      content="Request Entity Too Large",
    )
    assert_eq(handled.val, 1)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with treats max_request_body_bytes=0 as empty-body only" {
  let app = new()
  let handled : Ref[Int] = Ref::new(0)
  app.post("/body", event => {
    handled.val += 1
    event.req.raw_body.length().to_string()
  })
  app.get("/healthy", _ => "ok")
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_request_body_bytes=0),
      )
    })
    wait_until_ready(port)

    let (empty_response, empty_body) = @http.post(
      localhost_url(port, "/body"),
      "",
      headers={ "Connection": "close" },
    )
    assert_eq(empty_response.code, 200)
    inspect(empty_body.text(), content="0")
    assert_eq(handled.val, 1)

    let (empty_chunked_headers, empty_chunked_body) = issue_raw_request_response(
      port, "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n0\r\n\r\n",
    )
    inspect(
      empty_chunked_headers.has_prefix("HTTP/1.1 200 OK").to_string(),
      content="true",
    )
    inspect(empty_chunked_body.trim(chars="\r\n"), content="0")
    assert_eq(handled.val, 2)

    let (fixed_response, fixed_body) = @http.post(
      localhost_url(port, "/body"),
      "x",
      headers={ "Connection": "close" },
    )
    assert_eq(fixed_response.code, 413)
    inspect(
      fixed_body.text().trim(chars="\r\n"),
      content="Request Entity Too Large",
    )
    assert_eq(handled.val, 2)

    let (chunked_headers, chunked_body) = issue_raw_request_response(
      port, "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n1\r\nx\r\n0\r\n\r\n",
    )
    inspect(
      chunked_headers
      .has_prefix("HTTP/1.1 413 RequestEntityTooLarge")
      .to_string(),
      content="true",
    )
    inspect(chunked_body.trim(chars="\r\n"), content="Request Entity Too Large")
    assert_eq(handled.val, 2)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with enforces max_request_body_bytes for chunked bodies" {
  let app = new()
  let handled : Ref[Int] = Ref::new(0)
  app.post("/body", event => {
    handled.val += 1
    event.req.raw_body
  })
  app.get("/healthy", _ => "ok")
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_request_body_bytes=4),
      )
    })
    wait_until_ready(port)

    let (headers, body) = issue_raw_request_response(
      port, "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n3\r\nmoo\r\n4\r\nnbit\r\n0\r\n\r\n",
    )
    inspect(
      headers.has_prefix("HTTP/1.1 413 RequestEntityTooLarge").to_string(),
      content="true",
    )
    inspect(
      raw_header_value(headers, "Connection").unwrap_or(""),
      content="close",
    )
    inspect(
      raw_header_value(headers, "Transfer-Encoding").unwrap_or("").to_lower(),
      content="chunked",
    )
    inspect(body.trim(chars="\r\n"), content="Request Entity Too Large")
    assert_eq(handled.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with accepts exact-limit chunked bodies across multiple reads" {
  let app = new()
  let handled : Ref[Int] = Ref::new(0)
  app.post("/body", event => {
    handled.val += 1
    event.req.raw_body.length().to_string()
  })
  app.get("/healthy", _ => "ok")
  app.get("/__mocket_ready", _ => "ready")
  let chunk1 = repeated_ascii_text("a", 1024)
  let chunk2 = repeated_ascii_text("b", 1024)
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_request_body_bytes=2048),
      )
    })
    wait_until_ready(port)

    let (headers, body) = issue_raw_request_response(
      port,
      "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n400\r\n\{chunk1}\r\n400\r\n\{chunk2}\r\n0\r\n\r\n",
    )
    inspect(headers.has_prefix("HTTP/1.1 200 OK").to_string(), content="true")
    inspect(body.trim(chars="\r\n"), content="2048")
    assert_eq(handled.val, 1)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_with rejects negative max_request_body_bytes" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(max_request_body_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidMaxRequestBodyBytes(-1)) => ()
    Err(err) => fail("unexpected invalid max_request_body_bytes error: \{err}")
    Ok(_) =>
      fail("expected serve_async_on_with to reject max_request_body_bytes=-1")
  }
}

///|
async test "serve_async_on_until_with rejects negative max_request_body_bytes" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_on_until_with(
    server,
    shutdown,
    NativeServeOptions::new(max_request_body_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidMaxRequestBodyBytes(-1)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_on_until_with max_request_body_bytes error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_on_until_with to reject max_request_body_bytes=-1",
      )
  }
}

///|
async test "serve_async_with rejects negative max_request_body_bytes" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(max_request_body_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidMaxRequestBodyBytes(-1)) => ()
    Err(err) => fail("unexpected invalid max_request_body_bytes error: \{err}")
    Ok(_) =>
      fail("expected serve_async_with to reject max_request_body_bytes=-1")
  }
}

///|
async test "serve_async_on_with rejects non-positive request_body_read_timeout_ms" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(request_body_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidRequestBodyReadTimeoutMs(0)) => ()
    Err(err) =>
      fail("unexpected invalid request_body_read_timeout_ms error: \{err}")
    Ok(_) =>
      fail(
        "expected serve_async_on_with to reject request_body_read_timeout_ms=0",
      )
  }
}

///|
async test "serve_async_on_until_with rejects non-positive request_body_read_timeout_ms" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_on_until_with(
    server,
    shutdown,
    NativeServeOptions::new(request_body_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidRequestBodyReadTimeoutMs(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_on_until_with request_body_read_timeout_ms error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_on_until_with to reject request_body_read_timeout_ms=0",
      )
  }
}

///|
async test "serve_async_with rejects non-positive request_body_read_timeout_ms" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(request_body_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidRequestBodyReadTimeoutMs(0)) => ()
    Err(err) =>
      fail("unexpected invalid request_body_read_timeout_ms error: \{err}")
    Ok(_) =>
      fail("expected serve_async_with to reject request_body_read_timeout_ms=0")
  }
}

///|
async test "serve_async_until_with rejects non-positive request_body_read_timeout_ms" {
  let app = new()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_until_with(
    port=0,
    shutdown,
    NativeServeOptions::new(request_body_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidRequestBodyReadTimeoutMs(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_until_with request_body_read_timeout_ms error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_until_with to reject request_body_read_timeout_ms=0",
      )
  }
}

///|
async test "serve_async_on_with rejects non-positive websocket_outgoing_queue_capacity" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(websocket_outgoing_queue_capacity=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketOutgoingQueueCapacity(0)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_outgoing_queue_capacity error: \{err}")
    Ok(_) =>
      fail(
        "expected serve_async_on_with to reject websocket_outgoing_queue_capacity=0",
      )
  }
}

///|
async test "serve_async_on_until_with rejects non-positive websocket_outgoing_queue_capacity" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_on_until_with(
    server,
    shutdown,
    NativeServeOptions::new(websocket_outgoing_queue_capacity=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketOutgoingQueueCapacity(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_on_until_with websocket_outgoing_queue_capacity error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_on_until_with to reject websocket_outgoing_queue_capacity=0",
      )
  }
}

///|
async test "serve_async_with rejects non-positive websocket_outgoing_queue_capacity" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(websocket_outgoing_queue_capacity=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketOutgoingQueueCapacity(0)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_outgoing_queue_capacity error: \{err}")
    Ok(_) =>
      fail(
        "expected serve_async_with to reject websocket_outgoing_queue_capacity=0",
      )
  }
}

///|
async test "serve_async_until_with rejects non-positive websocket_outgoing_queue_capacity" {
  let app = new()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_until_with(
    port=0,
    shutdown,
    NativeServeOptions::new(websocket_outgoing_queue_capacity=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketOutgoingQueueCapacity(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_until_with websocket_outgoing_queue_capacity error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_until_with to reject websocket_outgoing_queue_capacity=0",
      )
  }
}

///|
async test "serve_async_on_with rejects non-positive websocket_read_timeout_ms" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(websocket_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketReadTimeoutMs(0)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_read_timeout_ms error: \{err}")
    Ok(_) =>
      fail("expected serve_async_on_with to reject websocket_read_timeout_ms=0")
  }
}

///|
async test "serve_async_on_until_with rejects non-positive websocket_read_timeout_ms" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_on_until_with(
    server,
    shutdown,
    NativeServeOptions::new(websocket_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketReadTimeoutMs(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_on_until_with websocket_read_timeout_ms error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_on_until_with to reject websocket_read_timeout_ms=0",
      )
  }
}

///|
async test "serve_async_with rejects non-positive websocket_read_timeout_ms" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(websocket_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketReadTimeoutMs(0)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_read_timeout_ms error: \{err}")
    Ok(_) =>
      fail("expected serve_async_with to reject websocket_read_timeout_ms=0")
  }
}

///|
async test "serve_async_until_with rejects non-positive websocket_read_timeout_ms" {
  let app = new()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_until_with(
    port=0,
    shutdown,
    NativeServeOptions::new(websocket_read_timeout_ms=0),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketReadTimeoutMs(0)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_until_with websocket_read_timeout_ms error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_until_with to reject websocket_read_timeout_ms=0",
      )
  }
}

///|
async test "serve_async_on_with rejects negative websocket_max_message_bytes" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let result : Result[Unit, Error] = try? app.serve_async_on_with(
    server,
    NativeServeOptions::new(websocket_max_message_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketMaxMessageBytes(-1)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_max_message_bytes error: \{err}")
    Ok(_) =>
      fail(
        "expected serve_async_on_with to reject websocket_max_message_bytes=-1",
      )
  }
}

///|
async test "serve_async_on_until_with rejects negative websocket_max_message_bytes" {
  let app = new()
  let server = allocate_test_server()
  defer server.close()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_on_until_with(
    server,
    shutdown,
    NativeServeOptions::new(websocket_max_message_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketMaxMessageBytes(-1)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_on_until_with websocket_max_message_bytes error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_on_until_with to reject websocket_max_message_bytes=-1",
      )
  }
}

///|
async test "serve_async_with rejects negative websocket_max_message_bytes" {
  let app = new()
  let result : Result[Unit, Error] = try? app.serve_async_with(
    port=0,
    NativeServeOptions::new(websocket_max_message_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketMaxMessageBytes(-1)) => ()
    Err(err) =>
      fail("unexpected invalid websocket_max_message_bytes error: \{err}")
    Ok(_) =>
      fail("expected serve_async_with to reject websocket_max_message_bytes=-1")
  }
}

///|
async test "serve_async_until_with rejects negative websocket_max_message_bytes" {
  let app = new()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_until_with(
    port=0,
    shutdown,
    NativeServeOptions::new(websocket_max_message_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidWebSocketMaxMessageBytes(-1)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_until_with websocket_max_message_bytes error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_until_with to reject websocket_max_message_bytes=-1",
      )
  }
}

///|
async test "serve_async_on_with times out slow request bodies" {
  let app = new()
  let handled : Ref[Int] = Ref::new(0)
  app.post("/body", event => {
    handled.val += 1
    event.req.raw_body
  })
  app.get("/healthy", _ => "ok")
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(request_body_read_timeout_ms=50),
      )
    })
    wait_until_ready(port)

    let addr = @socket.Addr::parse("127.0.0.1:\{port}") catch {
      _ => fail("invalid slow-upload address")
    }
    let client = @socket.Tcp::connect(addr)
    defer client.close()
    client.write(
      "POST /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 7\r\nConnection: close\r\n\r\nmoo",
    )
    @async.sleep(150)
    let (headers, body) = read_raw_http_response(client)
    inspect(
      headers.has_prefix("HTTP/1.1 408 RequestTimeout").to_string(),
      content="true",
    )
    inspect(
      raw_header_value(headers, "Connection").unwrap_or(""),
      content="close",
    )
    inspect(
      raw_header_value(headers, "Transfer-Encoding").unwrap_or("").to_lower(),
      content="chunked",
    )
    inspect(body.trim(chars="\r\n"), content="Request Timeout")
    assert_eq(handled.val, 0)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_until_with rejects negative max_request_body_bytes" {
  let app = new()
  let shutdown = @async.Queue::new(kind=Unbounded)
  let result : Result[Unit, Error] = try? app.serve_async_until_with(
    port=0,
    shutdown,
    NativeServeOptions::new(max_request_body_bytes=-1),
  )
  match result {
    Err(NativeServeError::InvalidMaxRequestBodyBytes(-1)) => ()
    Err(err) =>
      fail(
        "unexpected serve_async_until_with max_request_body_bytes error: \{err}",
      )
    Ok(_) =>
      fail(
        "expected serve_async_until_with to reject max_request_body_bytes=-1",
      )
  }
}

///|
async test "serve_async_on_with preserves head content-length for oversized requests" {
  let app = new()
  app.get("/healthy", _ => "ok")
  app.get("/body", _ => "body")
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => {
      app.serve_async_on_with(
        server,
        NativeServeOptions::new(max_request_body_bytes=4),
      )
    })
    wait_until_ready(port)

    let headers = issue_raw_request_headers(
      port, "HEAD /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 7\r\nConnection: close\r\n\r\nmoonbit",
    )
    inspect(
      headers.has_prefix("HTTP/1.1 413 RequestEntityTooLarge").to_string(),
      content="true",
    )
    inspect(
      raw_header_value(headers, "Connection").unwrap_or(""),
      content="close",
    )
    inspect(
      raw_header_value(headers, "Content-Length").unwrap_or(""),
      content="24",
    )
    inspect(
      raw_header_value(headers, "Transfer-Encoding").unwrap_or(""),
      content="",
    )

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async matches middleware base paths by segment boundary" {
  let log : Array[String] = []
  let app = new()
  app.use_middleware(
    (event, next) => {
      log.push(event.req.path())
      next()
    },
    base_path="/api/",
  )
  app.get("/api", _ => "api-root")
  app.get("/api/", _ => "api-root-slash")
  app.get("/api/users", _ => "api")
  app.get("/apiary", _ => "apiary")
  with_test_server(app, port => {
    let (api_root_response, api_root_body) = @http.get(
      localhost_url(port, "/api?role=admin"),
    )
    assert_eq(api_root_response.code, 200)
    inspect(api_root_body.text(), content="api-root")

    let (api_root_slash_response, api_root_slash_body) = @http.get(
      localhost_url(port, "/api/?role=admin"),
    )
    assert_eq(api_root_slash_response.code, 200)
    inspect(api_root_slash_body.text(), content="api-root-slash")

    let (api_response, api_body) = @http.get(
      localhost_url(port, "/api/users?role=admin"),
    )
    assert_eq(api_response.code, 200)
    inspect(api_body.text(), content="api")

    let (apiary_response, apiary_body) = @http.get(
      localhost_url(port, "/apiary?role=admin"),
    )
    assert_eq(apiary_response.code, 200)
    inspect(apiary_body.text(), content="apiary")

    inspect(log.join(","), content="/api,/api/,/api/users")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until stops on shutdown signal" {
  let app = new()
  app.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server, shutdown)
    })
    wait_until_ready(port)

    let (response, body) = @http.get(localhost_url(port, "/__mocket_ready"))
    assert_eq(response.code, 200)
    inspect(body.text(), content="ready")

    shutdown.put(())

    match @async.with_timeout_opt(200, () => task.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected shutdown-signal stop without runtime failure: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for serve_async_on_until to stop after shutdown signal",
        )
    }
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until broadcasts shutdown when the queue is closed" {
  let app1 = new()
  let app2 = new()
  app1.get("/__mocket_ready", _ => "ready")
  app2.get("/__mocket_ready", _ => "ready")
  @async.with_task_group(group => {
    let server1 = allocate_test_server()
    let server2 = allocate_test_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task1 = group.spawn(no_wait=true, () => {
      try? app1.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app2.serve_async_on_until(server2, shutdown)
    })
    wait_until_ready(port1)
    wait_until_ready(port2)

    shutdown.close()

    match @async.with_timeout_opt(200, () => task1.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected queue close to stop the first server cleanly: \{err}",
            )
        }
      None =>
        fail("timed out waiting for the first server to stop after queue close")
    }
    match @async.with_timeout_opt(200, () => task2.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected queue close to stop the second server cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for the second server to stop after queue close",
        )
    }
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_until binds by port and stops on shutdown signal" {
  let app = new()
  app.get("/__mocket_ready", _ => "ready")
  let start_offset = @async.now().to_int() % 20_000
  for attempt = 0; attempt < 2_048; attempt = attempt + 1 {
    let port = 40_000 + (start_offset + attempt) % 20_000
    let attempt_result : Result[Bool, Error] = try? @async.with_task_group(group => {
      let shutdown = @async.Queue::new(kind=Unbounded)
      let task = group.spawn(no_wait=true, () => {
        try? app.serve_async_until(port~, shutdown)
      })
      match @async.with_timeout_opt(50, () => task.wait()) {
        Some(result) =>
          match result {
            Ok(_) => fail("serve_async_until exited before shutdown signal")
            Err(@os_error.OSError(errno, ..)) if errno == 1 =>
              raise SocketBindUnavailable
            Err(@os_error.OSError(_) as err) if err.is_EACCES() =>
              raise SocketBindUnavailable
            Err(@os_error.OSError(errno, ..)) if errno == 48 ||
              errno == 98 ||
              errno == 10048 => false
            Err(err) => raise err
          }
        None => {
          wait_until_ready(port)
          let (response, body) = @http.get(
            localhost_url(port, "/__mocket_ready"),
          )
          assert_eq(response.code, 200)
          inspect(body.text(), content="ready")
          shutdown.put(())
          match @async.with_timeout_opt(200, () => task.wait()) {
            Some(result) =>
              match result {
                Ok(_) => true
                Err(err) =>
                  fail(
                    "expected serve_async_until to stop without runtime failure: \{err}",
                  )
              }
            None =>
              fail(
                "timed out waiting for serve_async_until to stop after shutdown signal",
              )
          }
        }
      }
    })
    match attempt_result {
      Ok(true) => return
      Ok(false) => ()
      Err(SocketBindUnavailable) => return
      Err(err) => raise err
    }
  }
  return
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

    let (response3, body3) = @http.get(
      localhost_url(port, "/assets/hello.txt?v=1"),
    )
    assert_eq(response3.code, 200)
    inspect(body3.text(), content="hi")

    let (response4, body4) = @http.get(localhost_url(port, "/assets?v=1"))
    assert_eq(response4.code, 200)
    inspect(body4.text(), content="index")

    let (response5, body5) = @http.get(localhost_url(port, "/assets/?v=1"))
    assert_eq(response5.code, 200)
    inspect(body5.text(), content="index")

    let (response6, _body6) = @http.post(
      localhost_url(port, "/assets/hello.txt"),
      "",
    )
    assert_eq(response6.code, 405)
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async serves static assets from the root mount" {
  let app = new()
  app.static_assets("", TestStaticProvider::{  })
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    group.spawn_bg(no_wait=true, () => app.serve_async_on(server))
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let (response, _body) = @http.get(localhost_url(port, "/"))
      guard response.code == 200 else { raise ServerNotReady }
    })

    let (index_response, index_body) = @http.get(localhost_url(port, "/"))
    assert_eq(index_response.code, 200)
    inspect(index_body.text(), content="index")

    let (file_response, file_body) = @http.get(
      localhost_url(port, "/hello.txt"),
    )
    assert_eq(file_response.code, 200)
    inspect(file_body.text(), content="hi")

    let (missing_response, missing_body) = @http.get(
      localhost_url(port, "/missing.txt"),
    )
    assert_eq(missing_response.code, 404)
    inspect(missing_body.text().trim(chars="\r\n"), content="Not Found")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async normalizes trailing-slash static mounts" {
  let app = new()
  app.static_assets("/assets/", TestStaticProvider::{  })
  with_test_server(app, port => {
    let (index_response, index_body) = @http.get(localhost_url(port, "/assets"))
    assert_eq(index_response.code, 200)
    inspect(index_body.text(), content="index")

    let (slash_response, slash_body) = @http.get(
      localhost_url(port, "/assets/"),
    )
    assert_eq(slash_response.code, 200)
    inspect(slash_body.text(), content="index")

    let (file_response, file_body) = @http.get(
      localhost_url(port, "/assets/hello.txt"),
    )
    assert_eq(file_response.code, 200)
    inspect(file_body.text(), content="hi")

    let (missing_response, missing_body) = @http.get(
      localhost_url(port, "/assetsx"),
    )
    assert_eq(missing_response.code, 404)
    inspect(missing_body.text().trim(chars="\r\n"), content="Not Found")
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
async test "serve_async binds by port and dispatches trace and connect routes" {
  let app = new()
  app.trace("/trace", _ => HttpResponse::new(OK).body("trace"))
  app.connect("/connect", _ => HttpResponse::new(OK).body("connect"))
  with_port_bound_test_server(app, port => {
    let (trace_response, trace_body) = issue_request(
      port,
      @http.Trace,
      "/trace",
    )
    assert_eq(trace_response.code, 200)
    inspect(@utf8.decode(trace_body) catch { _ => "" }, content="trace")

    let (connect_response, connect_body) = issue_request(
      port,
      @http.Connect,
      "/connect",
    )
    assert_eq(connect_response.code, 200)
    inspect(@utf8.decode(connect_body) catch { _ => "" }, content="connect")
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
async test "serve_async drops oldest buffered websocket messages on overflow when configured" {
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(peer) => {
        peer.text("one")
        peer.text("two")
        peer.text("three")
      }
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(
      websocket_outgoing_queue_capacity=2,
      websocket_overflow_policy=NativeWebSocketOverflowPolicy::DropOldest,
    ),
    port => {
      let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer client.close()

      inspect(client.recv().read_all().text(), content="two")
      inspect(client.recv().read_all().text(), content="three")
      inspect(
        @async.with_timeout_opt(100, () => client.recv().read_all().text()),
        content="None",
      )

      client.send_close()
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async drops oldest buffered websocket messages by default" {
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(peer) => {
        peer.text("one")
        peer.text("two")
        peer.text("three")
      }
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_outgoing_queue_capacity=2),
    port => {
      let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer client.close()

      inspect(client.recv().read_all().text(), content="two")
      inspect(client.recv().read_all().text(), content="three")
      inspect(
        @async.with_timeout_opt(100, () => client.recv().read_all().text()),
        content="None",
      )

      client.send_close()
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async drops latest buffered websocket messages on overflow when configured" {
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(peer) => {
        peer.text("one")
        peer.text("two")
        peer.text("three")
      }
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(
      websocket_outgoing_queue_capacity=2,
      websocket_overflow_policy=NativeWebSocketOverflowPolicy::DropLatest,
    ),
    port => {
      let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer client.close()

      inspect(client.recv().read_all().text(), content="one")
      inspect(client.recv().read_all().text(), content="two")
      inspect(
        @async.with_timeout_opt(100, () => client.recv().read_all().text()),
        content="None",
      )

      client.send_close()
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async closes websocket clients after read timeout between messages" {
  let log : Array[String] = []
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, Text(text)) => peer.text("echo:\{text}")
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_read_timeout_ms=50),
    port => {
      let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer client.close()

      client.send_text("ping")
      inspect(client.recv().read_all().text(), content="echo:ping")

      match
        @async.with_timeout_opt(250, () => try? client.recv().read_all().text()) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::GoingAway,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket read timeout")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected websocket read timeout close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected websocket read timeout closure, got error: \{err}")
        Some(Ok(text)) =>
          fail("expected websocket read timeout closure, got text: \{text}")
        None => fail("timed out waiting for websocket read timeout closure")
      }

      @async.retry(@async.FixedDelay(20), max_retry=50, () => {
        guard log.contains("open") && log.contains("close") else {
          raise ServerNotReady
        }
      })

      let (healthy_response, healthy_body) = @http.get(
        localhost_url(port, "/healthy"),
      )
      assert_eq(healthy_response.code, 200)
      inspect(healthy_body.text(), content="ok")
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async closes oversized websocket text messages and stays healthy" {
  let log : Array[String] = []
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, Text(text)) => {
        log.push("text:\{text}")
        peer.text("echo:\{text}")
      }
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_max_message_bytes=4),
    port => {
      let oversized_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer oversized_client.close()

      oversized_client.send_text("12345")
      match
        @async.with_timeout_opt(300, () => {
          try? oversized_client.recv().read_all().text()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::MessageTooBig,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket message too big")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected oversized websocket text close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected oversized websocket text closure, got error: \{err}")
        Some(Ok(text)) =>
          fail("expected oversized websocket text closure, got text: \{text}")
        None => fail("timed out waiting for oversized websocket text closure")
      }

      @async.retry(@async.FixedDelay(20), max_retry=50, () => {
        guard log.contains("open") && log.contains("close") else {
          raise ServerNotReady
        }
        guard !log.contains("text:12345") else {
          fail("oversized websocket text message reached the handler")
        }
      })

      let healthy_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer healthy_client.close()

      healthy_client.send_text("1234")
      inspect(healthy_client.recv().read_all().text(), content="echo:1234")
      healthy_client.send_close()

      let (healthy_response, healthy_body) = @http.get(
        localhost_url(port, "/healthy"),
      )
      assert_eq(healthy_response.code, 200)
      inspect(healthy_body.text(), content="ok")
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async closes oversized websocket binary messages" {
  let log : Array[String] = []
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, Binary(bytes)) => {
        log.push("binary:\{bytes.length()}")
        peer.binary(bytes)
      }
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_max_message_bytes=4),
    port => {
      let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer client.close()

      client.send_binary([0, 1, 2, 3, 4])
      match
        @async.with_timeout_opt(300, () => {
          try? client.recv().read_all().binary()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::MessageTooBig,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket message too big")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected oversized websocket binary close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected oversized websocket binary closure, got error: \{err}")
        Some(Ok(bytes)) =>
          fail(
            "expected oversized websocket binary closure, got \{bytes.length()} bytes",
          )
        None => fail("timed out waiting for oversized websocket binary closure")
      }

      @async.retry(@async.FixedDelay(20), max_retry=50, () => {
        guard log.contains("open") && log.contains("close") else {
          raise ServerNotReady
        }
        guard !log.contains("binary:5") else {
          fail("oversized websocket binary message reached the handler")
        }
      })
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async treats websocket_max_message_bytes=0 as empty-message only" {
  let log : Array[String] = []
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, Text(text)) => {
        log.push("text:\{text.length()}")
        peer.text("text:\{text.length()}")
      }
      Message(peer, Binary(bytes)) => {
        log.push("binary:\{bytes.length()}")
        peer.text("binary:\{bytes.length()}")
      }
      Close(_) => log.push("close")
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_max_message_bytes=0),
    port => {
      let empty_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer empty_client.close()

      empty_client.send_text("")
      inspect(empty_client.recv().read_all().text(), content="text:0")

      empty_client.send_binary(b"")
      inspect(empty_client.recv().read_all().text(), content="binary:0")
      empty_client.send_close()

      let oversized_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer oversized_client.close()

      oversized_client.send_text("x")
      match
        @async.with_timeout_opt(300, () => {
          try? oversized_client.recv().read_all().text()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::MessageTooBig,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket message too big")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected zero-limit websocket close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected zero-limit websocket closure, got error: \{err}")
        Some(Ok(text)) =>
          fail("expected zero-limit websocket closure, got text: \{text}")
        None => fail("timed out waiting for zero-limit websocket closure")
      }

      let oversized_binary_client = @websocket.connect(
        "ws://127.0.0.1:\{port}/ws",
      )
      defer oversized_binary_client.close()

      oversized_binary_client.send_binary([0])
      match
        @async.with_timeout_opt(300, () => {
          try? oversized_binary_client.recv().read_all().text()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::MessageTooBig,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket message too big")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected zero-limit websocket binary close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail(
            "expected zero-limit websocket binary closure, got error: \{err}",
          )
        Some(Ok(text)) =>
          fail(
            "expected zero-limit websocket binary closure, got text: \{text}",
          )
        None =>
          fail("timed out waiting for zero-limit websocket binary closure")
      }

      let healthy_ws_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer healthy_ws_client.close()

      healthy_ws_client.send_text("")
      inspect(healthy_ws_client.recv().read_all().text(), content="text:0")
      healthy_ws_client.send_close()

      @async.retry(@async.FixedDelay(20), max_retry=50, () => {
        guard log.contains("text:0") &&
          log.contains("binary:0") &&
          log.contains("close") else {
          raise ServerNotReady
        }
        guard !log.contains("text:1") else {
          fail("non-empty websocket message passed through zero-byte limit")
        }
        guard !log.contains("binary:1") else {
          fail("non-empty websocket binary passed through zero-byte limit")
        }
      })

      let (healthy_response, healthy_body) = @http.get(
        localhost_url(port, "/healthy"),
      )
      assert_eq(healthy_response.code, 200)
      inspect(healthy_body.text(), content="ok")
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async enforces websocket_max_message_bytes across multiple reads" {
  let log : Array[String] = []
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Message(peer, Text(text)) => {
        log.push("text:\{text.length()}")
        peer.text(text.length().to_string())
      }
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server_options(
    app,
    NativeServeOptions::new(websocket_max_message_bytes=1536),
    port => {
      let oversized_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer oversized_client.close()

      oversized_client.send_text(repeated_ascii_text("a", 1537))
      match
        @async.with_timeout_opt(300, () => {
          try? oversized_client.recv().read_all().text()
        }) {
        Some(
          Err(
            @websocket.ConnectionClosed(
              @websocket.CloseCode::MessageTooBig,
              Some(reason)
            )
          )
        ) => inspect(reason, content="websocket message too big")
        Some(Err(@websocket.ConnectionClosed(code, reason))) =>
          fail(
            "expected multi-read websocket limit close code, got \{code} / \{reason}",
          )
        Some(Err(err)) =>
          fail("expected multi-read websocket limit closure, got error: \{err}")
        Some(Ok(text)) =>
          fail("expected multi-read websocket limit closure, got text: \{text}")
        None => fail("timed out waiting for multi-read websocket limit closure")
      }

      @async.retry(@async.FixedDelay(20), max_retry=50, () => {
        guard log.contains("open") && log.contains("close") else {
          raise ServerNotReady
        }
        guard !log.contains("text:1537") else {
          fail("oversized multi-read websocket message reached the handler")
        }
      })

      let exact_limit_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
      defer exact_limit_client.close()

      exact_limit_client.send_text(repeated_ascii_text("a", 1536))
      inspect(exact_limit_client.recv().read_all().text(), content="1536")
      exact_limit_client.send_close()
    },
  ) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async rejects websocket upgrades for http-only routes" {
  let handled : Ref[Int] = Ref::new(0)
  let app = new()
  app.get("/ws", _ => {
    handled.val += 1
    "http route"
  })
  app.get("/healthy", _ => "ok")
  with_test_server(app, port => {
    let (upgrade_headers, upgrade_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n",
    )
    assert_true(upgrade_headers.has_prefix("HTTP/1.1 404 "))
    assert_eq(
      raw_header_value(upgrade_headers, "content-type"),
      Some("text/plain; charset=utf-8"),
    )
    assert_eq(raw_header_value(upgrade_headers, "connection"), Some("close"))
    inspect(upgrade_body, content="Not Found")
    assert_eq(handled.val, 0)

    let (tabbed_upgrade_headers, tabbed_upgrade_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive,\tUpgrade\t\r\nUpgrade: \tWebSocket\t\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n",
    )
    assert_true(tabbed_upgrade_headers.has_prefix("HTTP/1.1 404 "))
    inspect(tabbed_upgrade_body, content="Not Found")
    assert_eq(handled.val, 0)

    let (header_only_response, header_only_body) = issue_request(
      port,
      Get,
      "/ws",
      headers={ "Upgrade": "websocket" },
    )
    assert_eq(header_only_response.code, 200)
    inspect(
      @utf8.decode(header_only_body) catch {
        _ => ""
      },
      content="http route",
    )
    assert_eq(handled.val, 1)

    let (http_response, http_body) = @http.get(localhost_url(port, "/ws"))
    assert_eq(http_response.code, 200)
    inspect(http_body.text(), content="http route")
    assert_eq(handled.val, 2)

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async accepts padded websocket handshake headers on matched routes" {
  let log : Array[String] = []
  let app = new()
  app.ws("/ws", event => {
    match event {
      Open(_) => log.push("open")
      Close(_) => log.push("close")
      _ => ()
    }
  })
  with_test_server(app, port => {
    let upgrade_headers = issue_raw_request_headers(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nCoNnEcTiOn: keep-alive,\tUpgrade\t\r\nUpGrAdE: \tWebSocket\t\r\nSeC-WeBsOcKeT-KeY: \tdGhlIHNhbXBsZSBub25jZQ==\t\r\nSeC-WeBsOcKeT-VeRsIoN: \t13\t\r\n\r\n",
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
async test "serve_async rejects invalid websocket handshakes on matched routes and stays healthy" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => peer.text(text)
      Close(_) => closed.val += 1
      _ => ()
    }
  })
  with_test_server(app, port => {
    let (invalid_headers, invalid_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\n\r\n",
    )
    assert_true(invalid_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(invalid_body.contains("Sec-WebSocket-Key"))
    assert_eq(opened.val, 0)
    assert_eq(closed.val, 0)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()

    client.send_text("ok")
    inspect(client.recv().read_all().text(), content="ok")
    client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async rejects unsupported websocket versions and non-get upgrades" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => peer.text(text)
      Close(_) => closed.val += 1
      _ => ()
    }
  })
  with_test_server(app, port => {
    let (version_headers, version_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: \t12\t\r\n\r\n",
    )
    assert_true(version_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(version_body.contains("version"))
    assert_eq(opened.val, 0)
    assert_eq(closed.val, 0)

    let (method_headers, method_body) = issue_raw_request_response(
      port, "POST /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nContent-Length: 4\r\n\r\ndata",
    )
    assert_true(method_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(method_body.contains("must be GET"))
    assert_eq(opened.val, 0)
    assert_eq(closed.val, 0)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()

    client.send_text("ok")
    inspect(client.recv().read_all().text(), content="ok")
    client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async closes the connection after rejected websocket upgrades" {
  let opened : Ref[Int] = Ref::new(0)
  let closed : Ref[Int] = Ref::new(0)
  let app = new()
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => opened.val += 1
      Message(peer, Text(text)) => peer.text(text)
      Close(_) => closed.val += 1
      _ => ()
    }
  })
  with_test_server(app, port => {
    let addr = @socket.Addr::parse("127.0.0.1:\{port}") catch {
      _ => fail("invalid raw request address")
    }
    let client = @socket.Tcp::connect(addr)
    defer client.close()

    client.write(
      "POST /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nContent-Length: 4\r\n\r\ndataGET /healthy HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
    )

    let (rejected_headers, rejected_body) = read_raw_http_response(client)
    assert_true(rejected_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(rejected_body.contains("must be GET"))
    assert_eq(opened.val, 0)
    assert_eq(closed.val, 0)

    let followup_headers = client.read_until("\r\n\r\n").unwrap_or("")
    assert_eq(followup_headers, "")

    let fresh_client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer fresh_client.close()

    fresh_client.send_text("ok")
    inspect(fresh_client.recv().read_all().text(), content="ok")
    fresh_client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard opened.val == 1 && closed.val == 1 else { raise ServerNotReady }
    })

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async rejects malformed websocket-like requests on websocket routes without stealing plain http" {
  let http_hits : Ref[Int] = Ref::new(0)
  let ws_opened : Ref[Int] = Ref::new(0)
  let ws_closed : Ref[Int] = Ref::new(0)
  let app = new()
  app.get("/ws", _ => {
    http_hits.val += 1
    "http route"
  })
  app.get("/healthy", _ => "ok")
  app.ws("/ws", event => {
    match event {
      Open(_) => ws_opened.val += 1
      Message(peer, Text(text)) => peer.text(text)
      Close(_) => ws_closed.val += 1
      _ => ()
    }
  })
  with_test_server(app, port => {
    let (plain_response, plain_body) = @http.get(localhost_url(port, "/ws"))
    assert_eq(plain_response.code, 200)
    inspect(plain_body.text(), content="http route")
    assert_eq(http_hits.val, 1)
    assert_eq(ws_opened.val, 0)
    assert_eq(ws_closed.val, 0)

    let (other_upgrade_headers, other_upgrade_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nUpgrade: h2c\r\n\r\n",
    )
    assert_true(other_upgrade_headers.has_prefix("HTTP/1.1 200 "))
    inspect(other_upgrade_body, content="http route")
    assert_eq(http_hits.val, 2)
    assert_eq(ws_opened.val, 0)
    assert_eq(ws_closed.val, 0)

    let (upgrade_only_headers, upgrade_only_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nConnection: close\r\n\r\n",
    )
    assert_true(upgrade_only_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(upgrade_only_body.contains("Connection"))
    assert_eq(http_hits.val, 2)
    assert_eq(ws_opened.val, 0)
    assert_eq(ws_closed.val, 0)

    let (connection_only_headers, connection_only_body) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n",
    )
    assert_true(connection_only_headers.has_prefix("HTTP/1.1 400 "))
    assert_true(connection_only_body.contains("Upgrade"))
    assert_eq(http_hits.val, 2)
    assert_eq(ws_opened.val, 0)
    assert_eq(ws_closed.val, 0)

    let (accept_only_headers, _) = issue_raw_request_response(
      port, "GET /ws HTTP/1.1\r\nHost: localhost\r\nSec-WebSocket-Accept: bogus\r\nConnection: close\r\n\r\n",
    )
    assert_true(accept_only_headers.has_prefix("HTTP/1.1 400 "))
    assert_eq(http_hits.val, 2)
    assert_eq(ws_opened.val, 0)
    assert_eq(ws_closed.val, 0)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()

    client.send_text("ok")
    inspect(client.recv().read_all().text(), content="ok")
    client.send_close()
    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard ws_opened.val == 1 && ws_closed.val == 1 else {
        raise ServerNotReady
      }
    })

    let (healthy_response, healthy_body) = @http.get(
      localhost_url(port, "/healthy"),
    )
    assert_eq(healthy_response.code, 200)
    inspect(healthy_body.text(), content="ok")
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
async test "serve_async lets close handlers publish to remaining websocket subscribers" {
  let app = new()
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      Close(peer) => peer.publish("room", "left")
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

    client1.send_close()
    match @async.with_timeout_opt(300, () => client2.recv().read_all().text()) {
      Some(message) => inspect(message, content="left")
      None => fail("timed out waiting for close handler fanout")
    }

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")
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

///|
async test "serve_async isolates websocket channels per server invocation when reusing one app" {
  let app = new()
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      _ => ()
    }
  })
  with_two_test_servers(app, app, (port1, port2) => {
    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    client1.send_text("publish")
    inspect(client1.recv().read_all().text(), content="fanout")
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

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
async test "serve_async isolates close-handler websocket fanout per reused app server" {
  let app = new()
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      Close(peer) => peer.publish("room", "left")
      _ => ()
    }
  })
  with_two_test_servers(app, app, (port1, port2) => {
    let client1a = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1a.close()
    let client1b = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1b.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    client1a.send_close()
    match
      @async.with_timeout_opt(300, () => client1b.recv().read_all().text()) {
      Some(message) => inspect(message, content="left")
      None => fail("timed out waiting for same-server close handler fanout")
    }
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

    client1b.send_text("publish")
    inspect(client1b.recv().read_all().text(), content="fanout")
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")
    inspect(
      @async.with_timeout_opt(100, () => client1b.recv().read_all().text()),
      content="None",
    )

    client1b.send_close()
    client2.send_close()
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async keeps other reused-app servers alive when one server is cancelled" {
  let app = new()
  app.get("/__mocket_ready", _ => "ready")
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      _ => ()
    }
  })
  @async.with_task_group(group => {
    let server1 = allocate_test_server()
    let server2 = allocate_test_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let task1 = group.spawn(no_wait=true, () => app.serve_async_on(server1))
    group.spawn_bg(no_wait=true, () => app.serve_async_on(server2))
    wait_until_ready(port1)
    wait_until_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    client1.send_text("publish")
    inspect(client1.recv().read_all().text(), content="fanout")
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

    task1.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task1.wait())),
      Some(()),
    )
    match
      @async.with_timeout_opt(300, () => try? client1.recv().read_all().text()) {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => inspect(reason, content="websocket server shutdown")
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected cancelled server websocket client to observe going-away close, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected cancelled server websocket client to observe shutdown close, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected cancelled server websocket client to observe shutdown close, got text: \{text}",
        )
      None =>
        fail("expected cancelled server websocket client to observe shutdown")
    }

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until sends going-away close to websocket clients on shutdown signal" {
  let app = new()
  app.get("/__mocket_ready", _ => "ready")
  app.ws("/ws", event => {
    match event {
      Message(peer, Text(text)) => peer.text(text)
      _ => ()
    }
  })
  @async.with_task_group(group => {
    let server = allocate_test_server()
    let port = server.addr.port()
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task = group.spawn(no_wait=true, () => {
      app.serve_async_on_until(server, shutdown)
    })
    wait_until_ready(port)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer client.close()

    client.send_text("ping")
    inspect(client.recv().read_all().text(), content="ping")

    shutdown.put(())
    match
      @async.with_timeout_opt(300, () => try? client.recv().read_all().text()) {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => inspect(reason, content="websocket server shutdown")
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected websocket shutdown signal to send going-away close, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected websocket shutdown signal to close client, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected websocket shutdown signal to close client, got text: \{text}",
        )
      None => fail("timed out waiting for websocket shutdown close")
    }

    match @async.with_timeout_opt(300, () => try? task.wait()) {
      Some(Ok(_)) => ()
      Some(Err(err)) =>
        fail(
          "expected websocket shutdown signal to stop server cleanly: \{err}",
        )
      None => fail("timed out waiting for websocket server shutdown")
    }
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until broadcasts going-away close when the shutdown queue is closed" {
  let app = new()
  app.get("/__mocket_ready", _ => "ready")
  app.ws("/ws", event => {
    match event {
      Message(peer, Text(text)) => peer.text(text)
      _ => ()
    }
  })
  @async.with_task_group(group => {
    let server1 = allocate_test_server()
    let server2 = allocate_test_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task1 = group.spawn(no_wait=true, () => {
      app.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      app.serve_async_on_until(server2, shutdown)
    })
    wait_until_ready(port1)
    wait_until_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/ws")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/ws")
    defer client2.close()

    client1.send_text("left")
    inspect(client1.recv().read_all().text(), content="left")
    client2.send_text("right")
    inspect(client2.recv().read_all().text(), content="right")

    shutdown.close()

    match
      @async.with_timeout_opt(300, () => try? client1.recv().read_all().text()) {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => inspect(reason, content="websocket server shutdown")
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected first websocket client to observe going-away close after queue close, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected first websocket client to close after queue close, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected first websocket client to close after queue close, got text: \{text}",
        )
      None => fail("timed out waiting for first websocket queue-close shutdown")
    }

    match
      @async.with_timeout_opt(300, () => try? client2.recv().read_all().text()) {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => inspect(reason, content="websocket server shutdown")
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected second websocket client to observe going-away close after queue close, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected second websocket client to close after queue close, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected second websocket client to close after queue close, got text: \{text}",
        )
      None =>
        fail("timed out waiting for second websocket queue-close shutdown")
    }

    match @async.with_timeout_opt(300, () => try? task1.wait()) {
      Some(Ok(_)) => ()
      Some(Err(err)) =>
        fail(
          "expected queue close to stop the first websocket server cleanly: \{err}",
        )
      None =>
        fail(
          "timed out waiting for the first websocket server to stop after queue close",
        )
    }
    match @async.with_timeout_opt(300, () => try? task2.wait()) {
      Some(Ok(_)) => ()
      Some(Err(err)) =>
        fail(
          "expected queue close to stop the second websocket server cleanly: \{err}",
        )
      None =>
        fail(
          "timed out waiting for the second websocket server to stop after queue close",
        )
    }
  }) catch {
    SocketBindUnavailable => return
    err => raise err
  }
}
