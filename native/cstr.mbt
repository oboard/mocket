///|
pub fn CStr::from_bytes(bytes : Bytes) -> (CStr, Rc[Bytes]) {
  if bytes[bytes.length() - 1] != 0x00 {
    abort("expected null-terminated byte strings")
  }
  let rc = Rc::from_bytes(bytes)
  let cstr = rc |> unsafe_coerce
  (cstr, rc)
}

///|
pub fn CStr::unsafe_from_byte_ptr(ptr : Ptr[Byte]) -> CStr {
  unsafe_coerce(ptr)
}

///|
pub fn CStr::unsafe_from_const_byte_ptr(ptr : ConstPtr[Byte]) -> CStr {
  unsafe_coerce(ptr)
}
