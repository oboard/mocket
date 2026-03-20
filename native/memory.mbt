///|
pub extern "c" fn malloc(count : UInt64) -> Ptr[Byte] = "moonbit_native_malloc"

///|
pub extern "c" fn free(ptr : Ptr[Byte]) = "moonbit_native_free"

///|
pub extern "c" fn realloc(ptr : Ptr[Byte], count : UInt64) -> Ptr[Byte] = "moonbit_native_realloc"

///|
pub extern "c" fn memset(ptr : Ptr[Byte], val : Byte, count : UInt64) = "moonbit_native_memset"

///|
pub extern "c" fn memcpy(
  dest : Ptr[Byte],
  src : ConstPtr[Byte],
  count : UInt64,
) = "moonbit_native_memcpy"

///|
pub extern "c" fn memmove(
  dest : Ptr[Byte],
  src : ConstPtr[Byte],
  count : UInt64,
) = "moonbit_native_memmove"

///|
pub extern "c" fn memcmp(
  a : ConstPtr[Byte],
  b : ConstPtr[Byte],
  count : UInt64,
) -> Int = "moonbit_native_memcmp"
