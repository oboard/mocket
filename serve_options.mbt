///|
pub suberror NativeServeError {
  InvalidMaxConnections(Int)
  InvalidMaxRequestBodyBytes(Int)
  InvalidRequestBodyReadTimeoutMs(Int)
  InvalidWebSocketMaxMessageBytes(Int)
  InvalidWebSocketOutgoingQueueCapacity(Int)
  InvalidWebSocketReadTimeoutMs(Int)
} derive(Debug, ToJson)

///|
pub(all) enum NativeWebSocketOverflowPolicy {
  DropOldest
  DropLatest
} derive(Debug, Eq)

///|
pub impl Show for NativeWebSocketOverflowPolicy with output(self, logger) {
  match self {
    DropOldest => logger.write_string("DropOldest")
    DropLatest => logger.write_string("DropLatest")
  }
}

///|
pub struct NativeServeOptions {
  max_connections : Int?
  max_request_body_bytes : Int?
  request_body_read_timeout_ms : Int?
  websocket_outgoing_queue_capacity : Int?
  websocket_overflow_policy : NativeWebSocketOverflowPolicy?
  websocket_read_timeout_ms : Int?
  websocket_max_message_bytes : Int?

  fn new(
    max_connections? : Int,
    max_request_body_bytes? : Int,
    request_body_read_timeout_ms? : Int,
    websocket_outgoing_queue_capacity? : Int,
    websocket_overflow_policy? : NativeWebSocketOverflowPolicy,
    websocket_read_timeout_ms? : Int,
    websocket_max_message_bytes? : Int,
  ) -> NativeServeOptions
}

///|
/// `max_connections`, if present, bounds concurrent accepted connections.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
/// `request_body_read_timeout_ms`, if present, rejects slow request bodies
/// with `408 Request Timeout`.
/// `websocket_max_message_bytes`, if present, closes websocket connections
/// with `1009 MessageTooBig` when an inbound message exceeds that many bytes.
/// `websocket_outgoing_queue_capacity`, if present, bounds buffered outbound
/// websocket messages per connection.
/// `websocket_overflow_policy`, if present, chooses whether a full outbound
/// websocket queue drops the oldest or latest message.
/// `websocket_read_timeout_ms`, if present, closes websocket connections
/// after that many milliseconds waiting for the next inbound message.
pub fn NativeServeOptions::new(
  max_connections? : Int,
  max_request_body_bytes? : Int,
  request_body_read_timeout_ms? : Int,
  websocket_outgoing_queue_capacity? : Int,
  websocket_overflow_policy? : NativeWebSocketOverflowPolicy,
  websocket_read_timeout_ms? : Int,
  websocket_max_message_bytes? : Int,
) -> NativeServeOptions {
  {
    max_connections,
    max_request_body_bytes,
    request_body_read_timeout_ms,
    websocket_outgoing_queue_capacity,
    websocket_overflow_policy,
    websocket_read_timeout_ms,
    websocket_max_message_bytes,
  }
}

///|
fn resolve_native_max_connections(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.max_connections {
    Some(max_connections) => {
      guard max_connections > 0 else {
        raise NativeServeError::InvalidMaxConnections(max_connections)
      }
      Some(max_connections)
    }
    None => None
  }
}

///|
fn resolve_native_max_request_body_bytes(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.max_request_body_bytes {
    Some(max_request_body_bytes) => {
      guard max_request_body_bytes >= 0 else {
        raise NativeServeError::InvalidMaxRequestBodyBytes(
          max_request_body_bytes,
        )
      }
      Some(max_request_body_bytes)
    }
    None => None
  }
}

///|
fn resolve_native_request_body_read_timeout_ms(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.request_body_read_timeout_ms {
    Some(request_body_read_timeout_ms) => {
      guard request_body_read_timeout_ms > 0 else {
        raise NativeServeError::InvalidRequestBodyReadTimeoutMs(
          request_body_read_timeout_ms,
        )
      }
      Some(request_body_read_timeout_ms)
    }
    None => None
  }
}

///|
fn resolve_native_websocket_max_message_bytes(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.websocket_max_message_bytes {
    Some(websocket_max_message_bytes) => {
      guard websocket_max_message_bytes >= 0 else {
        raise NativeServeError::InvalidWebSocketMaxMessageBytes(
          websocket_max_message_bytes,
        )
      }
      Some(websocket_max_message_bytes)
    }
    None => None
  }
}

///|
fn resolve_native_websocket_outgoing_queue_capacity(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.websocket_outgoing_queue_capacity {
    Some(websocket_outgoing_queue_capacity) => {
      guard websocket_outgoing_queue_capacity > 0 else {
        raise NativeServeError::InvalidWebSocketOutgoingQueueCapacity(
          websocket_outgoing_queue_capacity,
        )
      }
      Some(websocket_outgoing_queue_capacity)
    }
    None => None
  }
}

///|
fn resolve_native_websocket_overflow_policy(
  options : NativeServeOptions,
) -> NativeWebSocketOverflowPolicy {
  match options.websocket_overflow_policy {
    Some(policy) =>
      match policy {
        NativeWebSocketOverflowPolicy::DropOldest =>
          NativeWebSocketOverflowPolicy::DropOldest
        NativeWebSocketOverflowPolicy::DropLatest =>
          NativeWebSocketOverflowPolicy::DropLatest
      }
    None => NativeWebSocketOverflowPolicy::DropOldest
  }
}

///|
fn resolve_native_websocket_read_timeout_ms(
  options : NativeServeOptions,
) -> Int? raise Error {
  match options.websocket_read_timeout_ms {
    Some(websocket_read_timeout_ms) => {
      guard websocket_read_timeout_ms > 0 else {
        raise NativeServeError::InvalidWebSocketReadTimeoutMs(
          websocket_read_timeout_ms,
        )
      }
      Some(websocket_read_timeout_ms)
    }
    None => None
  }
}
