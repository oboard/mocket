///|
test "resolve_native_max_connections returns None when unset" {
  let result = resolve_native_max_connections(NativeServeOptions::new())
  inspect(result, content="None")
}

///|
test "resolve_native_max_connections accepts positive value" {
  let result = resolve_native_max_connections(
    NativeServeOptions::new(max_connections=5),
  )
  inspect(result, content="Some(5)")
}

///|
test "resolve_native_max_connections rejects zero" {
  let result : Result[Int?, Error] = try? resolve_native_max_connections(
    NativeServeOptions::new(max_connections=0),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_max_connections rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_max_connections(
    NativeServeOptions::new(max_connections=-1),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_max_request_body_bytes returns None when unset" {
  let result = resolve_native_max_request_body_bytes(NativeServeOptions::new())
  inspect(result, content="None")
}

///|
test "resolve_native_max_request_body_bytes accepts zero" {
  let result = resolve_native_max_request_body_bytes(
    NativeServeOptions::new(max_request_body_bytes=0),
  )
  inspect(result, content="Some(0)")
}

///|
test "resolve_native_max_request_body_bytes accepts positive value" {
  let result = resolve_native_max_request_body_bytes(
    NativeServeOptions::new(max_request_body_bytes=1024),
  )
  inspect(result, content="Some(1024)")
}

///|
test "resolve_native_max_request_body_bytes rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_max_request_body_bytes(
    NativeServeOptions::new(max_request_body_bytes=-1),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_request_body_read_timeout_ms returns None when unset" {
  let result = resolve_native_request_body_read_timeout_ms(
    NativeServeOptions::new(),
  )
  inspect(result, content="None")
}

///|
test "resolve_native_request_body_read_timeout_ms accepts positive value" {
  let result = resolve_native_request_body_read_timeout_ms(
    NativeServeOptions::new(request_body_read_timeout_ms=100),
  )
  inspect(result, content="Some(100)")
}

///|
test "resolve_native_request_body_read_timeout_ms rejects zero" {
  let result : Result[Int?, Error] = try? resolve_native_request_body_read_timeout_ms(
    NativeServeOptions::new(request_body_read_timeout_ms=0),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_request_body_read_timeout_ms rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_request_body_read_timeout_ms(
    NativeServeOptions::new(request_body_read_timeout_ms=-1),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_websocket_max_message_bytes returns None when unset" {
  let result = resolve_native_websocket_max_message_bytes(
    NativeServeOptions::new(),
  )
  inspect(result, content="None")
}

///|
test "resolve_native_websocket_max_message_bytes accepts zero" {
  let result = resolve_native_websocket_max_message_bytes(
    NativeServeOptions::new(websocket_max_message_bytes=0),
  )
  inspect(result, content="Some(0)")
}

///|
test "resolve_native_websocket_max_message_bytes accepts positive value" {
  let result = resolve_native_websocket_max_message_bytes(
    NativeServeOptions::new(websocket_max_message_bytes=1024),
  )
  inspect(result, content="Some(1024)")
}

///|
test "resolve_native_websocket_max_message_bytes rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_websocket_max_message_bytes(
    NativeServeOptions::new(websocket_max_message_bytes=-1),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_websocket_outgoing_queue_capacity returns None when unset" {
  let result = resolve_native_websocket_outgoing_queue_capacity(
    NativeServeOptions::new(),
  )
  inspect(result, content="None")
}

///|
test "resolve_native_websocket_outgoing_queue_capacity accepts positive value" {
  let result = resolve_native_websocket_outgoing_queue_capacity(
    NativeServeOptions::new(websocket_outgoing_queue_capacity=10),
  )
  inspect(result, content="Some(10)")
}

///|
test "resolve_native_websocket_outgoing_queue_capacity rejects zero" {
  let result : Result[Int?, Error] = try? resolve_native_websocket_outgoing_queue_capacity(
    NativeServeOptions::new(websocket_outgoing_queue_capacity=0),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_websocket_outgoing_queue_capacity rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_websocket_outgoing_queue_capacity(
    NativeServeOptions::new(websocket_outgoing_queue_capacity=-1),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_websocket_overflow_policy defaults to DropOldest" {
  let result = resolve_native_websocket_overflow_policy(
    NativeServeOptions::new(),
  )
  assert_eq(result, DropOldest)
}

///|
test "resolve_native_websocket_overflow_policy returns DropOldest" {
  let result = resolve_native_websocket_overflow_policy(
    NativeServeOptions::new(websocket_overflow_policy=DropOldest),
  )
  assert_eq(result, DropOldest)
}

///|
test "resolve_native_websocket_overflow_policy returns DropLatest" {
  let result = resolve_native_websocket_overflow_policy(
    NativeServeOptions::new(websocket_overflow_policy=DropLatest),
  )
  assert_eq(result, DropLatest)
}

///|
test "resolve_native_websocket_read_timeout_ms returns None when unset" {
  let result = resolve_native_websocket_read_timeout_ms(
    NativeServeOptions::new(),
  )
  inspect(result, content="None")
}

///|
test "resolve_native_websocket_read_timeout_ms accepts positive value" {
  let result = resolve_native_websocket_read_timeout_ms(
    NativeServeOptions::new(websocket_read_timeout_ms=100),
  )
  inspect(result, content="Some(100)")
}

///|
test "resolve_native_websocket_read_timeout_ms rejects zero" {
  let result : Result[Int?, Error] = try? resolve_native_websocket_read_timeout_ms(
    NativeServeOptions::new(websocket_read_timeout_ms=0),
  )
  inspect(result is Err(_), content="true")
}

///|
test "resolve_native_websocket_read_timeout_ms rejects negative" {
  let result : Result[Int?, Error] = try? resolve_native_websocket_read_timeout_ms(
    NativeServeOptions::new(websocket_read_timeout_ms=-1),
  )
  inspect(result is Err(_), content="true")
}
