///|
pub fn[T : Getter] ConstPtr::get(self : ConstPtr[T]) -> T {
  T::get(self)
}

///|
pub fn[T] ConstPtr::compare(self : ConstPtr[T], other : ConstPtr[T]) -> Int {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(other)).to_int()
}

///|
pub fn[T : Sized] ConstPtr::add(
  self : ConstPtr[T],
  offset : Int64,
) -> ConstPtr[T] {
  self |> unsafe_coerce |> pointer_add(offset * T::size()) |> unsafe_coerce
}

///|
pub fn[T : Sized] ConstPtr::sub(
  self : ConstPtr[T],
  other : ConstPtr[T],
) -> Int64 {
  let lhs = unsafe_coerce(self)
  let rhs = unsafe_coerce(other)
  pointer_sub(lhs, rhs) / T::size()
}

///|
pub fn[T] ConstPtr::from_rc_fixedarray(rc : Rc[FixedArray[T]]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}

///|
pub fn[T] ConstPtr::from_rc_bytes(rc : Rc[Bytes]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}

///|
pub fn[T] ConstPtr::from_rc_string(rc : Rc[String]) -> ConstPtr[T] {
  unsafe_coerce(rc)
}
