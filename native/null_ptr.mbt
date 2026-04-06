///|

///|
let null_pointer : ConstPtr[Unit] = _null_pointer() |> unsafe_coerce

///|
/// Returns a null mutable pointer.
pub fn[T] Ptr::null_pointer() -> Ptr[T] {
  unsafe_coerce(null_pointer)
}

///|
/// Returns `true` if this mutable pointer is null.
pub fn[T] Ptr::is_null(self : Ptr[T]) -> Bool {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(null_pointer)) == 0
}

///|
/// Returns a null const pointer.
pub fn[T] ConstPtr::null_pointer() -> ConstPtr[T] {
  unsafe_coerce(null_pointer)
}

///|
/// Returns `true` if this const pointer is null.
pub fn[T] ConstPtr::is_null(self : ConstPtr[T]) -> Bool {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(null_pointer)) == 0
}
