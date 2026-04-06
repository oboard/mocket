///|
/// Size of a `Byte` in bytes.
pub let size_of_byte = 1L

///|
/// Size of an `Int16` in bytes.
pub let size_of_int16 = 2L

///|
/// Size of a `Char` in bytes.
pub let size_of_char = 4L

///|
/// Size of an `Int` (32-bit) in bytes.
pub let size_of_int = 4L

///|
/// Size of an `Int64` in bytes.
pub let size_of_int64 = 8L

///|
/// Size of a `UInt16` in bytes.
pub let size_of_uint16 = 2L

///|
/// Size of a `UInt` (32-bit) in bytes.
pub let size_of_uint = 4L

///|
/// Size of a `UInt64` in bytes.
pub let size_of_uint64 = 8L

///|
/// Size of a `Float` (32-bit) in bytes.
pub let size_of_float = 4L

///|
/// Size of a `Double` (64-bit) in bytes.
pub let size_of_double = 8L

///|
pub impl Sized for Byte with size() {
  size_of_byte
}

///|
pub impl Sized for Char with size() {
  size_of_char
}

///|
pub impl Sized for Int16 with size() {
  size_of_int16
}

///|
pub impl Sized for Int with size() {
  size_of_int
}

///|
pub impl Sized for Int64 with size() {
  size_of_int64
}

///|
pub impl Sized for UInt16 with size() {
  size_of_uint16
}

///|
pub impl Sized for UInt with size() {
  size_of_uint
}

///|
pub impl Sized for UInt64 with size() {
  size_of_uint64
}

///|
pub impl Sized for Float with size() {
  size_of_float
}

///|
pub impl Sized for Double with size() {
  size_of_double
}
