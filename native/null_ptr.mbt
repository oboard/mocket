///|

///|
let null_pointer : ConstPtr[Unit] = _null_pointer() |> unsafe_coerce

///|
pub fn[T] Ptr::null_pointer() -> Ptr[T] {
  unsafe_coerce(null_pointer)
}

///|
pub fn[T] Ptr::is_null(self : Ptr[T]) -> Bool {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(null_pointer)) == 0
}

///|
pub fn[T] ConstPtr::null_pointer() -> ConstPtr[T] {
  unsafe_coerce(null_pointer)
}

///|
pub fn[T] ConstPtr::is_null(self : ConstPtr[T]) -> Bool {
  pointer_sub(unsafe_coerce(self), unsafe_coerce(null_pointer)) == 0
}
