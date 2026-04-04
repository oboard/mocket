///|
pub suberror NativeServeError {
  InvalidMaxConnections(Int)
  InvalidMaxRequestBodyBytes(Int)
} derive(Show, ToJson)

///|
pub struct NativeServeOptions {
  max_connections : Int?
  max_request_body_bytes : Int?
}

///|
/// `max_connections`, if present, bounds concurrent accepted connections.
/// `max_request_body_bytes`, if present, rejects oversized request bodies
/// with `413 Request Entity Too Large`.
pub fn NativeServeOptions::new(
  max_connections? : Int,
  max_request_body_bytes? : Int,
) -> NativeServeOptions {
  { max_connections, max_request_body_bytes }
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
