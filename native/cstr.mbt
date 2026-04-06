///|
/// Creates a `CStr` from a null-terminated byte buffer, returning the string and its owning `Rc`.
pub fn CStr::from_bytes(bytes : Bytes) -> (CStr, Rc[Bytes]) {
  if bytes[bytes.length() - 1] != 0x00 {
    abort("expected null-terminated byte strings")
  }
  let rc = Rc::from_bytes(bytes)
  let cstr = rc |> unsafe_coerce
  (cstr, rc)
}

///|
/// Unsafely creates a `CStr` from a mutable byte pointer without checking for null termination.
pub fn CStr::unsafe_from_byte_ptr(ptr : Ptr[Byte]) -> CStr {
  unsafe_coerce(ptr)
}

///|
/// Unsafely creates a `CStr` from a const byte pointer without checking for null termination.
pub fn CStr::unsafe_from_const_byte_ptr(ptr : ConstPtr[Byte]) -> CStr {
  unsafe_coerce(ptr)
}
