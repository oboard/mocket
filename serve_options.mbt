///|
pub suberror NativeServeError {
  InvalidMaxConnections(Int)
} derive(Show, ToJson)

///|
pub struct NativeServeOptions {
  max_connections : Int?
}

///|
pub fn NativeServeOptions::new(max_connections? : Int) -> NativeServeOptions {
  { max_connections, }
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
