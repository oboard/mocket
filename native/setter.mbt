///|
pub impl Setter for Byte with set(self : Ptr[Byte], x : Byte) {
  byte_pointer_set(self, x)
}

///|
pub impl Setter for Char with set(self : Ptr[Char], x : Char) {
  int32_pointer_set(unsafe_coerce(self), unsafe_coerce(x))
}

///|
pub impl Setter for Int16 with set(self : Ptr[Int16], x : Int16) {
  int16_pointer_set(self, x)
}

///|
pub impl Setter for Int with set(self : Ptr[Int], x : Int) {
  int32_pointer_set(self, x)
}

///|
pub impl Setter for Int64 with set(self : Ptr[Int64], x : Int64) {
  int64_pointer_set(self, x)
}

///|
pub impl Setter for UInt16 with set(self : Ptr[UInt16], x : UInt16) {
  uint16_pointer_set(self, x)
}

///|
pub impl Setter for UInt with set(self : Ptr[UInt], x : UInt) {
  uint32_pointer_set(self, x)
}

///|
pub impl Setter for UInt64 with set(self : Ptr[UInt64], x : UInt64) {
  uint64_pointer_set(self, x)
}

///|
pub impl Setter for Float with set(self : Ptr[Float], x : Float) {
  float_pointer_set(self, x)
}

///|
pub impl Setter for Double with set(self : Ptr[Double], x : Double) {
  double_pointer_set(self, x)
}
