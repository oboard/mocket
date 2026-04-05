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
fn native_ws_channel_member_count(channel : String) -> Int {
  let mut count = 0
  native_ws_hubs.each((_runtime_id, hub) => {
    match hub.channels.get(channel) {
      Some(members) => members.each((_member_id, _) => count += 1)
      None => ()
    }
  })
  count
}

///|
fn native_ws_runtime_ids_for_app(app : Mocket) -> Array[String] {
  let runtime_ids : Array[String] = []
  let prefix = app.ws_runtime_id + "/"
  native_ws_hubs.each((runtime_id, _hub) => {
    match runtime_id.find(prefix) {
      Some(0) => runtime_ids.push(runtime_id)
      _ => ()
    }
  })
  runtime_ids
}

///|
fn native_ws_channel_member_count_in_runtime(
  runtime_id : String,
  channel : String,
) -> Int {
  match native_ws_hubs.get(runtime_id) {
    Some(hub) =>
      match hub.channels.get(channel) {
        Some(members) => {
          let mut count = 0
          members.each((_member_id, _) => count += 1)
          count
        }
        None => 0
      }
    None => 0
  }
}

///|
fn native_ws_connection_exists(connection_id : String) -> Bool {
  native_ws_connection_hubs.get(connection_id) is Some(_)
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
    let shutdown = @async.Queue::new(kind=Blocking(0))
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

///|
async test "serve_async_on removes websocket channel subscriptions on close" {
  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let channel = "room-close-cleanup-\{port}"
    let app = new()
    app.get("/__ws_lifecycle_ready", _ => "ready")
    app.ws("/hub", event => {
      match event {
        Open(peer) => peer.subscribe(channel)
        Message(peer, Text("publish")) => peer.publish(channel, "fanout")
        _ => ()
      }
    })
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client1.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 0 else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on makes closed websocket peers inert after unregister" {
  let closed_peer : Ref[WebSocketPeer?] = Ref::new(None)
  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let channel = "room-stale-peer-\{port}"
    let app = new()
    app.get("/__ws_lifecycle_ready", _ => "ready")
    app.ws("/hub", event => {
      match event {
        Open(peer) => peer.subscribe(channel)
        Message(peer, Text("publish")) => peer.publish(channel, "fanout")
        Message(_, Text("poke-stale")) =>
          match closed_peer.val {
            Some(peer) => {
              peer.text("ghost-direct")
              peer.publish(channel, "ghost-publish")
            }
            None => ()
          }
        Close(peer) => closed_peer.val = Some(peer)
        _ => ()
      }
    })
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client2.close()

    client1.send_text("publish")
    inspect(client1.recv().read_all().text(), content="fanout")
    inspect(client2.recv().read_all().text(), content="fanout")

    client1.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      match closed_peer.val {
        Some(peer) => {
          guard !native_ws_connection_exists(peer.connection_id) &&
            native_ws_channel_member_count(channel) == 1 else {
            raise WebSocketLifecycleServerNotReady
          }
        }
        None => raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("poke-stale")
    inspect(
      @async.with_timeout_opt(100, () => client2.recv().read_all().text()),
      content="None",
    )

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 0 else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on closes outgoing queues before close-handler cleanup" {
  let close_connection_id : Ref[String?] = Ref::new(None)
  let close_saw_registered : Ref[Bool?] = Ref::new(None)
  let close_saw_queue_closed : Ref[Bool?] = Ref::new(None)
  let close_channel_members : Ref[Int?] = Ref::new(None)
  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let channel = "room-close-order-\{port}"
    let app = new()
    app.get("/__ws_lifecycle_ready", _ => "ready")
    app.ws("/hub", event => {
      match event {
        Open(peer) => peer.subscribe(channel)
        Message(peer, Text("publish")) => peer.publish(channel, "fanout")
        Close(peer) => {
          close_connection_id.val = Some(peer.connection_id)
          close_channel_members.val = Some(
            native_ws_channel_member_count(channel),
          )
          match resolve_native_ws_connection(peer.connection_id) {
            Some((_, connection)) => {
              close_saw_registered.val = Some(true)
              let queue_put_result : Result[Bool, Error] = try? connection.outgoing.try_put(
                SendText("ghost"),
              )
              close_saw_queue_closed.val = Some(
                match queue_put_result {
                  Err(_) => true
                  _ => false
                },
              )
            }
            None => {
              close_saw_registered.val = Some(false)
              close_saw_queue_closed.val = Some(false)
            }
          }
        }
        _ => ()
      }
    })
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client1.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard close_connection_id.val is Some(_) &&
        close_saw_registered.val is Some(_) &&
        close_saw_queue_closed.val is Some(_) &&
        close_channel_members.val is Some(_) else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    inspect(close_saw_registered.val, content="Some(true)")
    inspect(close_saw_queue_closed.val, content="Some(true)")
    inspect(close_channel_members.val, content="Some(2)")

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      match close_connection_id.val {
        Some(connection_id) => {
          guard !native_ws_connection_exists(connection_id) &&
            native_ws_channel_member_count(channel) == 1 else {
            raise WebSocketLifecycleServerNotReady
          }
        }
        None => raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(channel) == 0 else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on cleans up subscriptions added during close handler" {
  let close_connection_id : Ref[String?] = Ref::new(None)
  let close_primary_members : Ref[Int?] = Ref::new(None)
  let close_late_members : Ref[Int?] = Ref::new(None)
  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let primary_channel = "room-close-primary-\{port}"
    let late_channel = "room-close-late-\{port}"
    let app = new()
    app.get("/__ws_lifecycle_ready", _ => "ready")
    app.ws("/hub", event => {
      match event {
        Open(peer) => peer.subscribe(primary_channel)
        Close(peer) => {
          close_connection_id.val = Some(peer.connection_id)
          peer.subscribe(late_channel)
          close_primary_members.val = Some(
            native_ws_channel_member_count(primary_channel),
          )
          close_late_members.val = Some(
            native_ws_channel_member_count(late_channel),
          )
        }
        _ => ()
      }
    })
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(primary_channel) == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard close_connection_id.val is Some(_) &&
        close_primary_members.val is Some(_) &&
        close_late_members.val is Some(_) else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    inspect(close_primary_members.val, content="Some(1)")
    inspect(close_late_members.val, content="Some(1)")

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      match close_connection_id.val {
        Some(connection_id) => {
          guard !native_ws_connection_exists(connection_id) &&
            native_ws_channel_member_count(primary_channel) == 0 &&
            native_ws_channel_member_count(late_channel) == 0 else {
            raise WebSocketLifecycleServerNotReady
          }
        }
        None => raise WebSocketLifecycleServerNotReady
      }
    })

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on handles unsubscribe then subscribe mutations during close handler" {
  let close_connection_id : Ref[String?] = Ref::new(None)
  let close_primary_members : Ref[Int?] = Ref::new(None)
  let close_late_members : Ref[Int?] = Ref::new(None)
  @async.with_task_group(group => {
    let server = allocate_websocket_lifecycle_server()
    let port = server.addr.port()
    let primary_channel = "room-close-swap-primary-\{port}"
    let late_channel = "room-close-swap-late-\{port}"
    let app = new()
    app.get("/__ws_lifecycle_ready", _ => "ready")
    app.ws("/hub", event => {
      match event {
        Open(peer) => peer.subscribe(primary_channel)
        Close(peer) => {
          close_connection_id.val = Some(peer.connection_id)
          peer.unsubscribe(primary_channel)
          peer.subscribe(late_channel)
          close_primary_members.val = Some(
            native_ws_channel_member_count(primary_channel),
          )
          close_late_members.val = Some(
            native_ws_channel_member_count(late_channel),
          )
        }
        _ => ()
      }
    })
    let task = group.spawn(no_wait=true, () => app.serve_async_on(server))
    wait_until_websocket_lifecycle_ready(port)

    let client = @websocket.connect("ws://127.0.0.1:\{port}/hub")
    defer client.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_channel_member_count(primary_channel) == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard close_connection_id.val is Some(_) &&
        close_primary_members.val is Some(_) &&
        close_late_members.val is Some(_) else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    inspect(close_primary_members.val, content="Some(0)")
    inspect(close_late_members.val, content="Some(1)")

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      match close_connection_id.val {
        Some(connection_id) => {
          guard !native_ws_connection_exists(connection_id) &&
            native_ws_channel_member_count(primary_channel) == 0 &&
            native_ws_channel_member_count(late_channel) == 0 else {
            raise WebSocketLifecycleServerNotReady
          }
        }
        None => raise WebSocketLifecycleServerNotReady
      }
    })

    task.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task.wait())),
      Some(()),
    )
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on keeps close-handler mutations isolated across reused app runtimes" {
  let close_runtime_id : Ref[String?] = Ref::new(None)
  let close_room_members : Ref[Int?] = Ref::new(None)
  let close_late_members : Ref[Int?] = Ref::new(None)
  let close_late_runtime_count : Ref[Int?] = Ref::new(None)
  let app = new()
  app.get("/__ws_lifecycle_ready", _ => "ready")
  app.ws("/hub", event => {
    match event {
      Open(peer) => peer.subscribe("room")
      Message(peer, Text("publish")) => peer.publish("room", "fanout")
      Close(peer) => {
        close_runtime_id.val = native_ws_connection_hubs.get(peer.connection_id)
        peer.subscribe("late")
        let runtime_ids = native_ws_runtime_ids_for_app(app)
        let mut room_members = 0
        let mut late_members = 0
        let mut late_runtime_count = 0
        for runtime_id in runtime_ids {
          let room_count = native_ws_channel_member_count_in_runtime(
            runtime_id, "room",
          )
          let late_count = native_ws_channel_member_count_in_runtime(
            runtime_id, "late",
          )
          room_members += room_count
          late_members += late_count
          if late_count > 0 {
            late_runtime_count += 1
          }
        }
        close_room_members.val = Some(room_members)
        close_late_members.val = Some(late_members)
        close_late_runtime_count.val = Some(late_runtime_count)
      }
      _ => ()
    }
  })

  @async.with_task_group(group => {
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let task1 = group.spawn(no_wait=true, () => app.serve_async_on(server1))
    let task2 = group.spawn(no_wait=true, () => app.serve_async_on(server2))
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    client1.send_close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard close_runtime_id.val is Some(_) &&
        close_room_members.val is Some(_) &&
        close_late_members.val is Some(_) &&
        close_late_runtime_count.val is Some(_) else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    inspect(close_room_members.val, content="Some(2)")
    inspect(close_late_members.val, content="Some(1)")
    inspect(close_late_runtime_count.val, content="Some(1)")

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
      let surviving_runtime_id = runtime_ids[0]
      guard native_ws_channel_member_count_in_runtime(
          surviving_runtime_id, "room",
        ) ==
        1 &&
        native_ws_channel_member_count_in_runtime(surviving_runtime_id, "late") ==
        0 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    task1.cancel()
    task2.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task1.wait())),
      Some(()),
    )
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task2.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_runtime_ids_for_app(app).is_empty() else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on cancellation stays isolated across reused app runtimes" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let task1 = group.spawn(no_wait=true, () => app.serve_async_on(server1))
    let task2 = group.spawn(no_wait=true, () => app.serve_async_on(server2))
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    task1.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task1.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
      let surviving_runtime_id = runtime_ids[0]
      guard native_ws_channel_member_count_in_runtime(
          surviving_runtime_id, "room",
        ) ==
        1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    task2.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task2.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_runtime_ids_for_app(app).is_empty() else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until shutdown stays isolated across reused app runtimes" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown1 = @async.Queue::new(kind=Unbounded)
    let shutdown2 = @async.Queue::new(kind=Unbounded)
    let task1 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server1, shutdown1)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server2, shutdown2)
    })
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    shutdown1.put(())
    match @async.with_timeout_opt(200, () => task1.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected first reused-app shutdown signal to stop cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for first reused-app shutdown signal to stop server",
        )
    }

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
      let surviving_runtime_id = runtime_ids[0]
      guard native_ws_channel_member_count_in_runtime(
          surviving_runtime_id, "room",
        ) ==
        1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    shutdown2.put(())
    match @async.with_timeout_opt(200, () => task2.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected second reused-app shutdown signal to stop cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for second reused-app shutdown signal to stop server",
        )
    }

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_runtime_ids_for_app(app).is_empty() else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until queue close clears reused app websocket runtimes" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Blocking(0))
    let task1 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server2, shutdown)
    })
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    shutdown.close()

    match @async.with_timeout_opt(200, () => task1.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected first reused-app queue-close shutdown to stop cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for first reused-app queue-close shutdown to stop server",
        )
    }
    match @async.with_timeout_opt(200, () => task2.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected second reused-app queue-close shutdown to stop cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for second reused-app queue-close shutdown to stop server",
        )
    }

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_runtime_ids_for_app(app).is_empty() else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until queue close clears remaining reused runtime after cancellation" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Unbounded)
    let task1 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server2, shutdown)
    })
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    task1.cancel()
    assert_eq(
      @async.with_timeout_opt(200, () => ignore(try? task1.wait())),
      Some(()),
    )

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 1 else {
        raise WebSocketLifecycleServerNotReady
      }
      let surviving_runtime_id = runtime_ids[0]
      guard native_ws_channel_member_count_in_runtime(
          surviving_runtime_id, "room",
        ) ==
        1 else {
        raise WebSocketLifecycleServerNotReady
      }
    })

    client2.send_text("publish")
    inspect(client2.recv().read_all().text(), content="fanout")

    shutdown.close()

    match @async.with_timeout_opt(200, () => task2.wait()) {
      Some(result) =>
        match result {
          Ok(_) => ()
          Err(err) =>
            fail(
              "expected surviving reused-app queue-close shutdown to stop cleanly: \{err}",
            )
        }
      None =>
        fail(
          "timed out waiting for surviving reused-app queue-close shutdown to stop server",
        )
    }

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      guard native_ws_runtime_ids_for_app(app).is_empty() else {
        raise WebSocketLifecycleServerNotReady
      }
    })
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until shutdown signal wakes one reused runtime" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Blocking(0))
    let task1 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server2, shutdown)
    })
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    shutdown.put(())
    let client1_after = @async.with_timeout_opt(300, () => {
      try? client1.recv().read_all().text()
    })
    let client2_after = @async.with_timeout_opt(300, () => {
      try? client2.recv().read_all().text()
    })

    match client1_after {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => {
        inspect(reason, content="websocket server shutdown")
        match client2_after {
          None => ()
          Some(Err(@websocket.ConnectionClosed(code, why))) =>
            fail(
              "expected only one reused runtime to stop after shutdown signal, but both websocket clients closed: \{code} / \{why}",
            )
          Some(Err(err)) =>
            fail(
              "expected sibling reused websocket runtime to stay alive after shutdown signal, got error: \{err}",
            )
          Some(Ok(text)) =>
            fail(
              "expected sibling reused websocket runtime to stay alive after shutdown signal, got text: \{text}",
            )
        }
        match @async.with_timeout_opt(200, () => task1.wait()) {
          Some(result) =>
            match result {
              Ok(_) => ()
              Err(err) =>
                fail("expected signaled reused runtime to stop cleanly: \{err}")
            }
          None => fail("timed out waiting for signaled reused runtime to stop")
        }
        @async.retry(@async.FixedDelay(20), max_retry=50, () => {
          let runtime_ids = native_ws_runtime_ids_for_app(app)
          guard runtime_ids.length() == 1 else {
            raise WebSocketLifecycleServerNotReady
          }
          let surviving_runtime_id = runtime_ids[0]
          guard native_ws_channel_member_count_in_runtime(
              surviving_runtime_id, "room",
            ) ==
            1 else {
            raise WebSocketLifecycleServerNotReady
          }
        })
        match @async.with_timeout_opt(100, () => task2.wait()) {
          Some(result) =>
            fail(
              "expected sibling reused runtime to stay alive after one shutdown signal, got \{result}",
            )
          None => ()
        }
        client2.send_text("publish")
        inspect(client2.recv().read_all().text(), content="fanout")
        try shutdown.try_put(()) catch {
          err =>
            fail(
              "expected second shutdown signal delivery to the surviving reused runtime to succeed: \{err}",
            )
        } noraise {
          delivered =>
            if !delivered {
              fail(
                "expected surviving reused runtime to remain blocked on the shutdown queue after one shutdown signal",
              )
            }
        }
        match @async.with_timeout_opt(200, () => task2.wait()) {
          Some(result) =>
            match result {
              Ok(_) => ()
              Err(err) =>
                fail(
                  "expected second shutdown signal to stop the surviving reused runtime cleanly: \{err}",
                )
            }
          None =>
            fail(
              "timed out waiting for the surviving reused runtime to stop after second shutdown signal",
            )
        }
        @async.retry(@async.FixedDelay(20), max_retry=50, () => {
          guard native_ws_runtime_ids_for_app(app).is_empty() else {
            raise WebSocketLifecycleServerNotReady
          }
        })
      }
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected stopped reused websocket client to observe going-away close after shutdown signal, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected stopped reused websocket client to observe shutdown close, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected stopped reused websocket client to observe shutdown close, got text: \{text}",
        )
      None =>
        match client2_after {
          Some(
            Err(
              @websocket.ConnectionClosed(
                @websocket.CloseCode::GoingAway,
                Some(reason)
              )
            )
          ) => {
            inspect(reason, content="websocket server shutdown")
            match @async.with_timeout_opt(200, () => task2.wait()) {
              Some(result) =>
                match result {
                  Ok(_) => ()
                  Err(err) =>
                    fail(
                      "expected signaled reused runtime to stop cleanly: \{err}",
                    )
                }
              None =>
                fail("timed out waiting for signaled reused runtime to stop")
            }
            @async.retry(@async.FixedDelay(20), max_retry=50, () => {
              let runtime_ids = native_ws_runtime_ids_for_app(app)
              guard runtime_ids.length() == 1 else {
                raise WebSocketLifecycleServerNotReady
              }
              let surviving_runtime_id = runtime_ids[0]
              guard native_ws_channel_member_count_in_runtime(
                  surviving_runtime_id, "room",
                ) ==
                1 else {
                raise WebSocketLifecycleServerNotReady
              }
            })
            match @async.with_timeout_opt(100, () => task1.wait()) {
              Some(result) =>
                fail(
                  "expected sibling reused runtime to stay alive after one shutdown signal, got \{result}",
                )
              None => ()
            }
            client1.send_text("publish")
            inspect(client1.recv().read_all().text(), content="fanout")
            try shutdown.try_put(()) catch {
              err =>
                fail(
                  "expected second shutdown signal delivery to the surviving reused runtime to succeed: \{err}",
                )
            } noraise {
              delivered =>
                if !delivered {
                  fail(
                    "expected surviving reused runtime to remain blocked on the shutdown queue after one shutdown signal",
                  )
                }
            }
            match @async.with_timeout_opt(200, () => task1.wait()) {
              Some(result) =>
                match result {
                  Ok(_) => ()
                  Err(err) =>
                    fail(
                      "expected second shutdown signal to stop the surviving reused runtime cleanly: \{err}",
                    )
                }
              None =>
                fail(
                  "timed out waiting for the surviving reused runtime to stop after second shutdown signal",
                )
            }
            @async.retry(@async.FixedDelay(20), max_retry=50, () => {
              guard native_ws_runtime_ids_for_app(app).is_empty() else {
                raise WebSocketLifecycleServerNotReady
              }
            })
          }
          Some(Err(@websocket.ConnectionClosed(code, reason))) =>
            fail(
              "expected exactly one reused websocket runtime to stop after shutdown signal, but got unexpected second close: \{code} / \{reason}",
            )
          Some(Err(err)) =>
            fail(
              "expected a reused websocket runtime to stop after shutdown signal, got error: \{err}",
            )
          Some(Ok(text)) =>
            fail(
              "expected a reused websocket runtime to stop after shutdown signal, got text: \{text}",
            )
          None =>
            fail(
              "expected exactly one reused websocket runtime to stop after shutdown signal",
            )
        }
    }
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
async test "serve_async_on_until queue close clears surviving reused runtime after shutdown signal" {
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
    let server1 = allocate_websocket_lifecycle_server()
    let server2 = allocate_websocket_lifecycle_server()
    let port1 = server1.addr.port()
    let port2 = server2.addr.port()
    let shutdown = @async.Queue::new(kind=Blocking(0))
    let task1 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server1, shutdown)
    })
    let task2 = group.spawn(no_wait=true, () => {
      try? app.serve_async_on_until(server2, shutdown)
    })
    wait_until_websocket_lifecycle_ready(port1)
    wait_until_websocket_lifecycle_ready(port2)

    let client1 = @websocket.connect("ws://127.0.0.1:\{port1}/hub")
    defer client1.close()
    let client2 = @websocket.connect("ws://127.0.0.1:\{port2}/hub")
    defer client2.close()

    @async.retry(@async.FixedDelay(20), max_retry=50, () => {
      let runtime_ids = native_ws_runtime_ids_for_app(app)
      guard runtime_ids.length() == 2 else {
        raise WebSocketLifecycleServerNotReady
      }
      let mut room_members = 0
      for runtime_id in runtime_ids {
        room_members += native_ws_channel_member_count_in_runtime(
          runtime_id, "room",
        )
      }
      guard room_members == 2 else { raise WebSocketLifecycleServerNotReady }
    })

    shutdown.put(())
    let client1_after = @async.with_timeout_opt(300, () => {
      try? client1.recv().read_all().text()
    })
    let client2_after = @async.with_timeout_opt(300, () => {
      try? client2.recv().read_all().text()
    })

    match client1_after {
      Some(
        Err(
          @websocket.ConnectionClosed(
            @websocket.CloseCode::GoingAway,
            Some(reason)
          )
        )
      ) => {
        inspect(reason, content="websocket server shutdown")
        match client2_after {
          None => ()
          Some(Err(@websocket.ConnectionClosed(code, why))) =>
            fail(
              "expected only one reused runtime to stop after shutdown signal, but both websocket clients closed: \{code} / \{why}",
            )
          Some(Err(err)) =>
            fail(
              "expected sibling reused websocket runtime to stay alive after shutdown signal, got error: \{err}",
            )
          Some(Ok(text)) =>
            fail(
              "expected sibling reused websocket runtime to stay alive after shutdown signal, got text: \{text}",
            )
        }
        match @async.with_timeout_opt(200, () => task1.wait()) {
          Some(result) =>
            match result {
              Ok(_) => ()
              Err(err) =>
                fail("expected signaled reused runtime to stop cleanly: \{err}")
            }
          None => fail("timed out waiting for signaled reused runtime to stop")
        }
        @async.retry(@async.FixedDelay(20), max_retry=50, () => {
          let runtime_ids = native_ws_runtime_ids_for_app(app)
          guard runtime_ids.length() == 1 else {
            raise WebSocketLifecycleServerNotReady
          }
          let surviving_runtime_id = runtime_ids[0]
          guard native_ws_channel_member_count_in_runtime(
              surviving_runtime_id, "room",
            ) ==
            1 else {
            raise WebSocketLifecycleServerNotReady
          }
        })
        match @async.with_timeout_opt(100, () => task2.wait()) {
          Some(result) =>
            fail(
              "expected sibling reused runtime to stay alive after one shutdown signal, got \{result}",
            )
          None => ()
        }
        client2.send_text("publish")
        inspect(client2.recv().read_all().text(), content="fanout")
        shutdown.close()
        match @async.with_timeout_opt(200, () => task2.wait()) {
          Some(result) =>
            match result {
              Ok(_) => ()
              Err(err) =>
                fail(
                  "expected queue close to stop the surviving reused runtime cleanly after shutdown signal: \{err}",
                )
            }
          None =>
            fail(
              "timed out waiting for the surviving reused runtime to stop after queue close",
            )
        }
        @async.retry(@async.FixedDelay(20), max_retry=50, () => {
          guard native_ws_runtime_ids_for_app(app).is_empty() else {
            raise WebSocketLifecycleServerNotReady
          }
        })
      }
      Some(Err(@websocket.ConnectionClosed(code, reason))) =>
        fail(
          "expected stopped reused websocket client to observe going-away close after shutdown signal, got \{code} / \{reason}",
        )
      Some(Err(err)) =>
        fail(
          "expected stopped reused websocket client to observe shutdown close, got error: \{err}",
        )
      Some(Ok(text)) =>
        fail(
          "expected stopped reused websocket client to observe shutdown close, got text: \{text}",
        )
      None =>
        match client2_after {
          Some(
            Err(
              @websocket.ConnectionClosed(
                @websocket.CloseCode::GoingAway,
                Some(reason)
              )
            )
          ) => {
            inspect(reason, content="websocket server shutdown")
            match @async.with_timeout_opt(200, () => task2.wait()) {
              Some(result) =>
                match result {
                  Ok(_) => ()
                  Err(err) =>
                    fail(
                      "expected signaled reused runtime to stop cleanly: \{err}",
                    )
                }
              None =>
                fail("timed out waiting for signaled reused runtime to stop")
            }
            @async.retry(@async.FixedDelay(20), max_retry=50, () => {
              let runtime_ids = native_ws_runtime_ids_for_app(app)
              guard runtime_ids.length() == 1 else {
                raise WebSocketLifecycleServerNotReady
              }
              let surviving_runtime_id = runtime_ids[0]
              guard native_ws_channel_member_count_in_runtime(
                  surviving_runtime_id, "room",
                ) ==
                1 else {
                raise WebSocketLifecycleServerNotReady
              }
            })
            match @async.with_timeout_opt(100, () => task1.wait()) {
              Some(result) =>
                fail(
                  "expected sibling reused runtime to stay alive after one shutdown signal, got \{result}",
                )
              None => ()
            }
            client1.send_text("publish")
            inspect(client1.recv().read_all().text(), content="fanout")
            shutdown.close()
            match @async.with_timeout_opt(200, () => task1.wait()) {
              Some(result) =>
                match result {
                  Ok(_) => ()
                  Err(err) =>
                    fail(
                      "expected queue close to stop the surviving reused runtime cleanly after shutdown signal: \{err}",
                    )
                }
              None =>
                fail(
                  "timed out waiting for the surviving reused runtime to stop after queue close",
                )
            }
            @async.retry(@async.FixedDelay(20), max_retry=50, () => {
              guard native_ws_runtime_ids_for_app(app).is_empty() else {
                raise WebSocketLifecycleServerNotReady
              }
            })
          }
          Some(Err(@websocket.ConnectionClosed(code, reason))) =>
            fail(
              "expected exactly one reused websocket runtime to stop after shutdown signal, but got unexpected second close: \{code} / \{reason}",
            )
          Some(Err(err)) =>
            fail(
              "expected a reused websocket runtime to stop after shutdown signal, got error: \{err}",
            )
          Some(Ok(text)) =>
            fail(
              "expected a reused websocket runtime to stop after shutdown signal, got text: \{text}",
            )
          None =>
            fail(
              "expected exactly one reused websocket runtime to stop after shutdown signal",
            )
        }
    }
  }) catch {
    WebSocketLifecycleSocketBindUnavailable => return
    err => raise err
  }
}

///|
test "ensure_native_ws_hub creates new hub for new runtime id" {
  let runtime_id = "test-ensure-hub-new"
  let hub = ensure_native_ws_hub(runtime_id)
  inspect(hub.connections.is_empty(), content="true")
  inspect(hub.connection_counter.val, content="0")
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "ensure_native_ws_hub returns existing hub for same runtime id" {
  let runtime_id = "test-ensure-hub-existing"
  let hub1 = ensure_native_ws_hub(runtime_id)
  hub1.connection_counter.val = 42
  let hub2 = ensure_native_ws_hub(runtime_id)
  inspect(hub2.connection_counter.val, content="42")
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "next_native_ws_connection_id increments counter and formats id" {
  let runtime_id = "test-conn-id"
  let hub = ensure_native_ws_hub(runtime_id)
  let id1 = next_native_ws_connection_id(runtime_id, hub)
  inspect(id1, content="test-conn-id:1")
  let id2 = next_native_ws_connection_id(runtime_id, hub)
  inspect(id2, content="test-conn-id:2")
  let id3 = next_native_ws_connection_id(runtime_id, hub)
  inspect(id3, content="test-conn-id:3")
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "register_native_ws_connection makes connection resolvable" {
  let runtime_id = "test-register"
  let connection_id = "test-register:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  inspect(
    resolve_native_ws_connection(connection_id) is Some(_),
    content="true",
  )
  inspect(native_ws_connection_exists(connection_id), content="true")
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "unregister_native_ws_connection makes connection unresolvable" {
  let runtime_id = "test-unregister"
  let connection_id = "test-unregister:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  inspect(native_ws_connection_exists(connection_id), content="true")
  unregister_native_ws_connection(connection_id)
  inspect(native_ws_connection_exists(connection_id), content="false")
  inspect(
    resolve_native_ws_connection(connection_id) is Some(_),
    content="false",
  )
}

///|
test "unregister_native_ws_connection removes hub when last connection removed" {
  let runtime_id = "test-unregister-hub-removal"
  let connection_id = "test-unregister-hub-removal:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  inspect(native_ws_hubs.get(runtime_id) is Some(_), content="true")
  unregister_native_ws_connection(connection_id)
  inspect(native_ws_hubs.get(runtime_id) is Some(_), content="false")
}

///|
test "ws_subscribe adds connection to channel" {
  let runtime_id = "test-subscribe"
  let connection_id = "test-subscribe:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_subscribe(connection_id, "channel-a")
  let channels = snapshot_native_ws_channels(connection_id)
  inspect(channels.length(), content="1")
  inspect(channels[0], content="channel-a")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "channel-a"),
    content="1",
  )
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "ws_subscribe is idempotent" {
  let runtime_id = "test-subscribe-idempotent"
  let connection_id = "test-subscribe-idempotent:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_subscribe(connection_id, "channel-a")
  ws_subscribe(connection_id, "channel-a")
  let channels = snapshot_native_ws_channels(connection_id)
  inspect(channels.length(), content="1")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "channel-a"),
    content="1",
  )
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "ws_unsubscribe removes connection from channel" {
  let runtime_id = "test-unsubscribe"
  let connection_id = "test-unsubscribe:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_subscribe(connection_id, "channel-a")
  ws_subscribe(connection_id, "channel-b")
  ws_unsubscribe(connection_id, "channel-a")
  let channels = snapshot_native_ws_channels(connection_id)
  inspect(channels.length(), content="1")
  inspect(channels[0], content="channel-b")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "channel-a"),
    content="0",
  )
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "channel-b"),
    content="1",
  )
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "ws_unsubscribe on non-subscribed channel is safe" {
  let runtime_id = "test-unsubscribe-noop"
  let connection_id = "test-unsubscribe-noop:1"
  let outgoing = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    connection_id,
    outgoing,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_unsubscribe(connection_id, "nonexistent-channel")
  let channels = snapshot_native_ws_channels(connection_id)
  inspect(channels.length(), content="0")
  cleanup_native_ws_runtime(runtime_id)
}

///|
test "decode_native_ws_message decodes text message" {
  match decode_native_ws_message(@websocket.MessageKind::Text, b"hello") {
    Text(s) => inspect(s, content="hello")
    Binary(_) => fail("expected text message")
  }
}

///|
test "decode_native_ws_message decodes binary message" {
  let data : Bytes = b"binary data"
  match decode_native_ws_message(@websocket.MessageKind::Binary, data) {
    Binary(b) => inspect(b == data, content="true")
    Text(_) => fail("expected binary message")
  }
}

///|
test "decode_native_ws_message decodes empty text" {
  match decode_native_ws_message(@websocket.MessageKind::Text, b"") {
    Text(s) => inspect(s, content="")
    Binary(_) => fail("expected text message")
  }
}

///|
test "decode_native_ws_message decodes empty binary" {
  match decode_native_ws_message(@websocket.MessageKind::Binary, b"") {
    Binary(b) => inspect(b.length(), content="0")
    Text(_) => fail("expected binary message")
  }
}

///|
test "next_native_ws_message_chunk_size returns 1024 when remaining is large" {
  inspect(next_native_ws_message_chunk_size(4096, 0), content="1024")
  inspect(next_native_ws_message_chunk_size(4096, 1024), content="1024")
  inspect(next_native_ws_message_chunk_size(4096, 2048), content="1024")
}

///|
test "next_native_ws_message_chunk_size returns 1024 when remaining is exactly 1024" {
  inspect(next_native_ws_message_chunk_size(2048, 1024), content="1024")
}

///|
test "next_native_ws_message_chunk_size returns remaining plus 1 when under 1024" {
  inspect(next_native_ws_message_chunk_size(1000, 500), content="501")
  inspect(next_native_ws_message_chunk_size(100, 90), content="11")
  inspect(next_native_ws_message_chunk_size(1, 0), content="2")
}

///|
test "native_ws_chunk_exceeds_limit detects exceeding limit" {
  inspect(native_ws_chunk_exceeds_limit(100, 90, 11), content="true")
  inspect(native_ws_chunk_exceeds_limit(100, 90, 10), content="false")
  inspect(native_ws_chunk_exceeds_limit(100, 90, 9), content="false")
  inspect(native_ws_chunk_exceeds_limit(100, 0, 101), content="true")
  inspect(native_ws_chunk_exceeds_limit(100, 0, 100), content="false")
}

///|
test "cleanup_native_ws_runtime removes all connections for runtime" {
  let runtime_id = "test-cleanup-runtime"
  let outgoing1 = @async.Queue::new(kind=Blocking(10))
  let outgoing2 = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    "test-cleanup-runtime:1",
    outgoing1,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  register_native_ws_connection(
    runtime_id,
    "test-cleanup-runtime:2",
    outgoing2,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_subscribe("test-cleanup-runtime:1", "room")
  ws_subscribe("test-cleanup-runtime:2", "room")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "room"),
    content="2",
  )
  inspect(native_ws_connection_exists("test-cleanup-runtime:1"), content="true")
  inspect(native_ws_connection_exists("test-cleanup-runtime:2"), content="true")
  cleanup_native_ws_runtime(runtime_id)
  inspect(
    native_ws_connection_exists("test-cleanup-runtime:1"),
    content="false",
  )
  inspect(
    native_ws_connection_exists("test-cleanup-runtime:2"),
    content="false",
  )
  inspect(native_ws_hubs.get(runtime_id) is Some(_), content="false")
}

///|
test "cleanup_native_ws_runtime is safe on nonexistent runtime" {
  cleanup_native_ws_runtime("nonexistent-runtime-id")
}

///|
test "multiple connections share same hub channel" {
  let runtime_id = "test-shared-channel"
  let outgoing1 = @async.Queue::new(kind=Blocking(10))
  let outgoing2 = @async.Queue::new(kind=Blocking(10))
  register_native_ws_connection(
    runtime_id,
    "test-shared-channel:1",
    outgoing1,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  register_native_ws_connection(
    runtime_id,
    "test-shared-channel:2",
    outgoing2,
    NativeWebSocketOverflowPolicy::DropOldest,
  )
  ws_subscribe("test-shared-channel:1", "shared-room")
  ws_subscribe("test-shared-channel:2", "shared-room")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "shared-room"),
    content="2",
  )
  ws_unsubscribe("test-shared-channel:1", "shared-room")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "shared-room"),
    content="1",
  )
  ws_unsubscribe("test-shared-channel:2", "shared-room")
  inspect(
    native_ws_channel_member_count_in_runtime(runtime_id, "shared-room"),
    content="0",
  )
  cleanup_native_ws_runtime(runtime_id)
}
