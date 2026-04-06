///|
/// Reinterprets a value of type `A` as type `B` without any conversion.
pub fn[A, B] unsafe_coerce(x : A) -> B = "%identity"

///|
extern "c" fn _release(rc : Rc[Unit]) = "moonbit_decref"

///|
/// Decrements the reference count, freeing the value when it reaches zero.
pub fn[T] Rc::release(self : Rc[T]) -> Unit {
  unsafe_coerce(_release)(self)
}

///|
/// Wraps a `Bytes` value in an `Rc` without copying.
pub fn Rc::from_bytes(xs : Bytes) -> Rc[Bytes] = "%identity"

///|
/// Wraps a `FixedArray` value in an `Rc` without copying.
pub fn[T] Rc::from_fixedarray(xs : FixedArray[T]) -> Rc[FixedArray[T]] = "%identity"

///|
/// Pins a `Bytes` value, passes its pointer and length to `f`, then releases the reference.
pub fn[R] Rc::scope_bytes(xs : Bytes, f : (ConstPtr[Byte], Int) -> R) -> R {
  let rc = Rc::from_bytes(xs)
  let ptr : ConstPtr[Byte] = unsafe_coerce(rc)
  let result = f(ptr, xs.length())
  rc.release()
  result
}

///|
/// Pins a `FixedArray`, passes its pointer and length to `f`, then releases the reference.
pub fn[T, R] Rc::scope_fixedarray(
  xs : FixedArray[T],
  f : (Ptr[T], Int) -> R,
) -> R {
  let rc = Rc::from_fixedarray(xs)
  let ptr : Ptr[T] = unsafe_coerce(rc)
  let result = f(ptr, xs.length())
  rc.release()
  result
}
