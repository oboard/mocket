///|
suberror WebSocketLifecycleServerNotReady

///|
suberror WebSocketLifecycleSocketBindUnavailable

///|
async fn allocate_websocket_lifecycle_server() -> @http.Server {
  let addr = @socket.Addr::parse("127.0.0.1:0") catch {
    _ => raise WebSocketLifecycleSocketBindUnavailable
  }
  let bind_check : Result[@http.Server, Error] = try? @http.Server::new(
    addr,
    reuse_addr=true,
  )
  match bind_check {
    Ok(server) => server
    Err(@os_error.OSError(errno, ..)) if errno == 1 =>
      raise WebSocketLifecycleSocketBindUnavailable
    Err(@os_error.OSError(_) as err) if err.is_EACCES() =>
      raise WebSocketLifecycleSocketBindUnavailable
    Err(err) => fail("unexpected bind check failure: \{err}")
  }
}

///|
fn websocket_lifecycle_url(port : Int, path : String) -> String {
  "http://127.0.0.1:\{port}\{path}"
}

///|
async fn wait_until_websocket_lifecycle_ready(port : Int) -> Unit {
  @async.retry(@async.FixedDelay(20), max_retry=50, () => {
    let (response, _body) = @http.get(
      websocket_lifecycle_url(port, "/__ws_lifecycle_ready"),
    )
    guard response.code == 200 else { raise WebSocketLifecycleServerNotReady }
  })
}

///|
fn native_ws_hub_count() -> Int {
  let mut count = 0
  native_ws_hubs.each((_runtime_id, _) => count += 1)
  count
}

///|
fn native_ws_connection_hub_count() -> Int {
  let mut count = 0
  native_ws_connection_hubs.each((_connection_id, _) => count += 1)
  count
}

///|
async test "serve_async_on clears websocket runtime state on cancellation" {
  let initial_hub_count = native_ws_hub_count()
  let initial_connection_hub_count = native_ws_connection_hub_count()

  let app = new()
  app.get("/__ws_lifecycle_ready", _ => "ready")
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      _ => ()
    }
  })

  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client.close()

    client.send_text("publish")
    inspect(client.recv().read_all().text(), content="fanout")

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_hub_count() > initial_hub_count &&
        native_ws_connection_hub_count() > initial_connection_hub_count else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_hub_count() == initial_hub_count &&
        native_ws_connection_hub_count() == initial_connection_hub_count else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}
