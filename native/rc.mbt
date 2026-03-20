///|
pub fn[A, B] unsafe_coerce(x : A) -> B = "%identity"

///|
extern "c" fn _release(rc : Rc[Unit]) = "moonbit_decref"

///|
pub fn[T] Rc::release(self : Rc[T]) -> Unit {
  unsafe_coerce(_release)(self)
}

///|
pub fn Rc::from_bytes(xs : Bytes) -> Rc[Bytes] = "%identity"

///|
pub fn[T] Rc::from_fixedarray(xs : FixedArray[T]) -> Rc[FixedArray[T]] = "%identity"

///|
pub fn[R] Rc::scope_bytes(xs : Bytes, f : (ConstPtr[Byte], Int) -> R) -> R {
  let rc = Rc::from_bytes(xs)
  let ptr : ConstPtr[Byte] = unsafe_coerce(rc)
  let result = f(ptr, xs.length())
  rc.release()
  result
}

///|
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
