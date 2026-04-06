///|
/// Allocates `count` bytes of uninitialized memory, returning a pointer to the allocation.
pub extern "c" fn malloc(count : UInt64) -> Ptr[Byte] = "moonbit_native_malloc"

///|
/// Frees memory previously allocated by `malloc` or `realloc`.
pub extern "c" fn free(ptr : Ptr[Byte]) = "moonbit_native_free"

///|
/// Resizes the memory block pointed to by `ptr` to `count` bytes, returning the new pointer.
pub extern "c" fn realloc(ptr : Ptr[Byte], count : UInt64) -> Ptr[Byte] = "moonbit_native_realloc"

///|
/// Fills `count` bytes of memory at `ptr` with the given byte value.
pub extern "c" fn memset(ptr : Ptr[Byte], val : Byte, count : UInt64) = "moonbit_native_memset"

///|
/// Copies `count` bytes from `src` to `dest`. The memory regions must not overlap.
pub extern "c" fn memcpy(
  dest : Ptr[Byte],
  src : ConstPtr[Byte],
  count : UInt64,
) = "moonbit_native_memcpy"

///|
/// Copies `count` bytes from `src` to `dest`, correctly handling overlapping memory regions.
pub extern "c" fn memmove(
  dest : Ptr[Byte],
  src : ConstPtr[Byte],
  count : UInt64,
) = "moonbit_native_memmove"

///|
/// Compares `count` bytes of memory at `a` and `b`, returning 0 if equal.
pub extern "c" fn memcmp(
  a : ConstPtr[Byte],
  b : ConstPtr[Byte],
  count : UInt64,
) -> Int = "moonbit_native_memcmp"
