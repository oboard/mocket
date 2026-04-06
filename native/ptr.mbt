///|
/// Writes a value to the memory location pointed to by this pointer.
pub fn[T : Setter] Ptr::set(self : Ptr[T], x : T) -> Unit {
  T::set(self, x)
}

///|
/// Reads the value at the memory location pointed to by this pointer.
pub fn[T : Getter] Ptr::get(self : Ptr[T]) -> T {
  T::get(unsafe_coerce(self))
}

///|
/// Converts this mutable pointer to a const pointer.
pub fn[T] Ptr::to_const_ptr(self : Ptr[T]) -> ConstPtr[T] {
  unsafe_coerce(self)
}

///|
/// Compares two pointers by their memory addresses.
pub fn[T] Ptr::compare(self : Ptr[T], other : Ptr[T]) -> Int {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(other)).to_int()
}

///|
/// Advances this pointer by the given number of elements.
pub fn[T : Sized] Ptr::add(self : Ptr[T], offset : Int64) -> Ptr[T] {
  self |> unsafe_coerce |> pointer_add(offset * T::size()) |> unsafe_coerce
}

///|
/// Returns the element distance between two pointers.
pub fn[T : Sized] Ptr::sub(self : Ptr[T], other : Ptr[T]) -> Int64 {
  let lhs = unsafe_coerce(self)
  let rhs = unsafe_coerce(other)
  pointer_sub(lhs, rhs) / T::size()
}

///|
/// Creates a mutable pointer from a reference-counted fixed array.
pub fn[T] Ptr::from_rc_fixedarray(rc : Rc[FixedArray[T]]) -> Ptr[T] {
  unsafe_coerce(rc)
}
