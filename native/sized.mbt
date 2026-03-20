///|
pub let size_of_byte = 1L

///|
pub let size_of_int16 = 2L

///|
pub let size_of_char = 4L

///|
pub let size_of_int = 4L

///|
pub let size_of_int64 = 8L

///|
pub let size_of_uint16 = 2L

///|
pub let size_of_uint = 4L

///|
pub let size_of_uint64 = 8L

///|
pub let size_of_float = 4L

///|
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
