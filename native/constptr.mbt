///|
/// Reads the value at the memory location pointed to by this const pointer.
pub fn[T : Getter] ConstPtr::get(self : ConstPtr[T]) -> T {
  T::get(self)
}

///|
/// Compares two const pointers by their memory addresses.
pub fn[T] ConstPtr::compare(self : ConstPtr[T], other : ConstPtr[T]) -> Int {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(other)).to_int()
}

///|
/// Advances this const pointer by the given number of elements.
pub fn[T : Sized] ConstPtr::add(
  self : ConstPtr[T],
  offset : Int64,
) -> ConstPtr[T] {
  self |> unsafe_coerce |> pointer_add(offset * T::size()) |> unsafe_coerce
}

///|
/// Returns the element distance between two const pointers.
pub fn[T : Sized] ConstPtr::sub(
  self : ConstPtr[T],
  other : ConstPtr[T],
) -> Int64 {
  let lhs = unsafe_coerce(self)
  let rhs = unsafe_coerce(other)
  pointer_sub(lhs, rhs) / T::size()
}

///|
/// Creates a const pointer from a reference-counted fixed array.
pub fn[T] ConstPtr::from_rc_fixedarray(rc : Rc[FixedArray[T]]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}

///|
/// Creates a const pointer from a reference-counted byte buffer.
pub fn[T] ConstPtr::from_rc_bytes(rc : Rc[Bytes]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}

///|
/// Creates a const pointer from a reference-counted string.
pub fn[T] ConstPtr::from_rc_string(rc : Rc[String]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}
