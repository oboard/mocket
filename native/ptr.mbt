///|
pub fn[T : Setter] Ptr::set(self : Ptr[T], x : T) -> Unit {
  T::set(self, x)
}

///|
pub fn[T : Getter] Ptr::get(self : Ptr[T]) -> T {
  T::get(unsafe_coerce(self))
}

///|
pub fn[T] Ptr::to_const_ptr(self : Ptr[T]) -> ConstPtr[T] {
  unsafe_coerce(self)
}

///|
pub fn[T] Ptr::compare(self : Ptr[T], other : Ptr[T]) -> Int {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(other)).to_int()
}

///|
pub fn[T : Sized] Ptr::add(self : Ptr[T], offset : Int64) -> Ptr[T] {
  self |> unsafe_coerce |> pointer_add(offset * T::size()) |> unsafe_coerce
}

///|
pub fn[T : Sized] Ptr::sub(self : Ptr[T], other : Ptr[T]) -> Int64 {
  let lhs = unsafe_coerce(self)
  let rhs = unsafe_coerce(other)
  pointer_sub(lhs, rhs) / T::size()
}

///|
pub fn[T] Ptr::from_rc_fixedarray(rc : Rc[FixedArray[T]]) -> Ptr[T] {
  unsafe_coerce(rc)
}
