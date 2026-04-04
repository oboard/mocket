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
fn test_native_ws_connection(
  capacity : Int,
  overflow_policy : NativeWebSocketOverflowPolicy,
) -> NativeWebSocketConnection {
  {
    outgoing: @async.Queue::new(kind=Blocking(capacity)),
    overflow_policy,
    subscribed_channels: Map::new(),
  }
}

///|
test "native websocket message limit helpers handle int max boundaries" {
  let max_int = 2_147_483_647
  inspect(next_native_ws_message_chunk_size(max_int, 0), content="1024")
  inspect(native_ws_chunk_exceeds_limit(max_int, max_int, 1), content="true")
  inspect(
    native_ws_chunk_exceeds_limit(max_int, max_int - 1, 1),
    content="false",
  )
}

///|
test "enqueue_native_ws_outgoing_to_connection drops oldest when configured" {
  let connection = test_native_ws_connection(
    2,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  enqueue_native_ws_outgoing_to_connection(connection, SendText("one"))
  enqueue_native_ws_outgoing_to_connection(connection, SendText("two"))
  enqueue_native_ws_outgoing_to_connection(connection, SendText("three"))

  match connection.outgoing.try_get() {
    Some(SendText(text)) => inspect(text, content="two")
    Some(_) => fail("unexpected first queued websocket message kind")
    None => fail("expected first queued websocket message")
  }
  match connection.outgoing.try_get() {
    Some(SendText(text)) => inspect(text, content="three")
    Some(_) => fail("unexpected second queued websocket message kind")
    None => fail("expected second queued websocket message")
  }
  inspect(connection.outgoing.try_get() is None, content="true")
}

///|
test "enqueue_native_ws_outgoing_to_connection drops latest when configured" {
  let connection = test_native_ws_connection(
    2,
    NativeWebSocketOverflowPolicy::DropLatest,
  )
  enqueue_native_ws_outgoing_to_connection(connection, SendText("one"))
  enqueue_native_ws_outgoing_to_connection(connection, SendText("two"))
  enqueue_native_ws_outgoing_to_connection(connection, SendText("three"))

  match connection.outgoing.try_get() {
    Some(SendText(text)) => inspect(text, content="one")
    Some(_) => fail("unexpected first queued websocket message kind")
    None => fail("expected first queued websocket message")
  }
  match connection.outgoing.try_get() {
    Some(SendText(text)) => inspect(text, content="two")
    Some(_) => fail("unexpected second queued websocket message kind")
    None => fail("expected second queued websocket message")
  }
  inspect(connection.outgoing.try_get() is None, content="true")
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

///|
async test "serve_async_on_until clears websocket runtime state on shutdown signal" {
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
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server, shutdown)
    })
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

    shutdown.put(())
    match @async.with_timeout_opt(200, () => task.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected websocket shutdown signal to stop without runtime failure: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for websocket runtime to stop after shutdown signal",
        )
    }

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
