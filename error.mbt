///|
/// Error type for I/O operations such as file reads or writes.
pub suberror IOError derive(Debug)

///|
/// Error type for network-related failures such as connection errors.
pub suberror NetworkError derive(Debug)

///|
/// Error type for execution failures such as subprocess errors.
pub suberror ExecError derive(Debug)
