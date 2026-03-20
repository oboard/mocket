///|
extern "c" fn pointer_add(
  ptr : ConstPtr[Byte],
  offset : Int64,
) -> ConstPtr[Byte] = "moonbit_native_pointer_add"

///|
extern "c" fn pointer_sub(
  ptr : ConstPtr[Byte],
  other : ConstPtr[Byte],
) -> Int64 = "moonbit_native_pointer_sub"

///|
pub extern "c" fn CStr::to_bytes(self : CStr) -> Bytes = "moonbit_native_cstring_to_bytes"

///|
extern "c" fn byte_pointer_get(ptr : ConstPtr[Byte]) -> Byte = "moonbit_native_uint8_pointer_get"

///|
extern "c" fn int16_pointer_get(ptr : ConstPtr[Int16]) -> Int16 = "moonbit_native_int16_pointer_get"

///|
extern "c" fn int32_pointer_get(ptr : ConstPtr[Int]) -> Int = "moonbit_native_int32_pointer_get"

///|
extern "c" fn int64_pointer_get(ptr : ConstPtr[Int64]) -> Int64 = "moonbit_native_int64_pointer_get"

///|
extern "c" fn uint16_pointer_get(ptr : ConstPtr[UInt16]) -> UInt16 = "moonbit_native_uint16_pointer_get"

///|
extern "c" fn uint32_pointer_get(ptr : ConstPtr[UInt]) -> UInt = "moonbit_native_uint32_pointer_get"

///|
extern "c" fn uint64_pointer_get(ptr : ConstPtr[UInt64]) -> UInt64 = "moonbit_native_uint64_pointer_get"

///|
extern "c" fn float_pointer_get(ptr : ConstPtr[Float]) -> Float = "moonbit_native_float_pointer_get"

///|
extern "c" fn double_pointer_get(ptr : ConstPtr[Double]) -> Double = "moonbit_native_double_pointer_get"

///|
extern "c" fn uint32_pointer_set(ptr : Ptr[UInt], x : UInt) = "moonbit_native_uint32_pointer_set"

///|
extern "c" fn uint64_pointer_set(ptr : Ptr[UInt64], x : UInt64) = "moonbit_native_uint64_pointer_set"

///|
extern "c" fn byte_pointer_set(ptr : Ptr[Byte], x : Byte) = "moonbit_native_uint8_pointer_set"

///|
extern "c" fn int16_pointer_set(ptr : Ptr[Int16], x : Int16) = "moonbit_native_int16_pointer_set"

///|
extern "c" fn int32_pointer_set(ptr : Ptr[Int], x : Int) = "moonbit_native_int32_pointer_set"

///|
extern "c" fn int64_pointer_set(ptr : Ptr[Int64], x : Int64) = "moonbit_native_int64_pointer_set"

///|
extern "c" fn uint16_pointer_set(ptr : Ptr[UInt16], x : UInt16) = "moonbit_native_uint16_pointer_set"

///|
extern "c" fn float_pointer_set(ptr : Ptr[Float], x : Float) = "moonbit_native_float_pointer_set"

///|
extern "c" fn double_pointer_set(ptr : Ptr[Double], x : Double) = "moonbit_native_double_pointer_set"

///|
extern "c" fn _null_pointer() -> ConstPtr[Unit] = "moonbit_native_null_pointer"
