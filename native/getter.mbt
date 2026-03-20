///|
pub impl Getter for Byte with get(self : ConstPtr[Byte]) {
  byte_pointer_get(self)
}

///|
pub impl Getter for Char with get(self : ConstPtr[Char]) {
  unsafe_coerce(int32_pointer_get(unsafe_coerce(self)))
}

///|
pub impl Getter for Int16 with get(self : ConstPtr[Int16]) {
  int16_pointer_get(self)
}

///|
pub impl Getter for Int with get(self : ConstPtr[Int]) {
  int32_pointer_get(self)
}

///|
pub impl Getter for Int64 with get(self : ConstPtr[Int64]) {
  int64_pointer_get(self)
}

///|
pub impl Getter for UInt16 with get(self : ConstPtr[UInt16]) {
  uint16_pointer_get(self)
}

///|
pub impl Getter for UInt with get(self : ConstPtr[UInt]) {
  uint32_pointer_get(self)
}

///|
pub impl Getter for UInt64 with get(self : ConstPtr[UInt64]) {
  uint64_pointer_get(self)
}

///|
pub impl Getter for Float with get(self : ConstPtr[Float]) {
  float_pointer_get(self)
}

///|
pub impl Getter for Double with get(self : ConstPtr[Double]) {
  double_pointer_get(self)
}
