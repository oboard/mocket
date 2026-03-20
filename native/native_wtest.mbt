///|
test "malloc" {
  let ptr = malloc(1024)
  free(ptr)
}

///|
test "realloc" {
  let ptr = malloc(1024)
  let ptr2 = realloc(ptr, 2048)
  free(ptr2)
}

///|
test "Rc::from_bytes" {
  let rc = Rc::from_bytes(b"")
  rc.release()
}

///|
test "Rc::from_fixedarray" {
  let rc = Rc::from_fixedarray([1, 2, 3])
  rc.release()
}

///|
test "Rc::bytes_scope" {
  let bytes = b"\x01\x02\x03\x04"
  let len = Rc::scope_bytes(bytes, fn(ptr, len) { len })
  assert_eq(len, bytes.length())
  let b = Rc::scope_bytes(bytes, fn(ptr, _) { ptr.get() })
  assert_eq(b, bytes[0])
}

///|
test "Rc::fixedarray_scope" {
  let arr : FixedArray[UInt] = [1, 2, 3, 4, 5]
  let len = Rc::scope_fixedarray(arr, fn(ptr, len) { len })
  assert_eq(len, arr.length())
  for i in 0..<arr.length() {
    let b = Rc::scope_fixedarray(arr, fn(ptr, _) { ptr.add(i.to_int64()).get() })
    assert_eq(b, arr[i])
  }
}

///|
test "memset" {
  let actual : FixedArray[UInt64] = [1, 2, 3, 4, 5]
  Rc::scope_fixedarray(actual, fn(src, len) {
    let len = (len.to_int64() * size_of_double).reinterpret_as_uint64()
    memset(src.reinterpret_as_byte_ptr(), 0, len)
  })
  let expected : FixedArray[UInt64] = [0, 0, 0, 0, 0]
  assert_eq(actual, expected)
}

///|
test "memcpy" {
  let actual : FixedArray[Int] = FixedArray::makei(10, fn(i) { i + 1 })
  let expected : FixedArray[Int] = [1, 2, 3, 4, 1, 2, 3, 4, 9, 10]
  Rc::scope_fixedarray(actual, fn(src, len) {
    let dest = src.add(4)
    let len = (4L * size_of_int).reinterpret_as_uint64()
    memcpy(
      dest.reinterpret_as_byte_ptr(),
      src.reinterpret_as_const_byte_ptr(),
      len,
    )
  })
  assert_eq(expected, actual)
}

///|
test "memmove" {
  let actual : FixedArray[Int] = FixedArray::makei(10, fn(i) { i + 1 })
  let expected : FixedArray[Int] = [1, 2, 3, 4, 1, 2, 3, 4, 9, 10]
  Rc::scope_fixedarray(actual, fn(src, len) {
    let dest = src.add(4)
    let len = (4L * size_of_int).reinterpret_as_uint64()
    memmove(
      dest.reinterpret_as_byte_ptr(),
      src.reinterpret_as_const_byte_ptr(),
      len,
    )
  })
  assert_eq(expected, actual)
}

///|
test "ConstCString::to_bytes" {
  let expected = b"hello world\x00"
  let actual = Rc::scope_bytes(expected, fn(ptr, _) {
    let cstr = CStr::unsafe_from_const_byte_ptr(ptr)
    cstr.to_bytes()
  })
  assert_eq(actual, expected)
}

///|
test "CString::to_bytes" {
  let expected = b"hello world\x00"
  let actual = Rc::scope_bytes(expected, fn(ptr, _) {
    let cstr = CStr::unsafe_from_const_byte_ptr(ptr)
    cstr.to_bytes()
  })
  assert_eq(actual, expected)
}

///|
test "memcpy2" {
  let lhs : FixedArray[Double] = [1.0, 2.0, 3.0, 4.0]
  let rhs : FixedArray[Double] = [1.0, 2.0, 3.0, 4.0, 5]
  let rc_lhs = Rc::from_fixedarray(lhs)
  let rc_rhs = Rc::from_fixedarray(rhs)
  let lhs_ptr = Ptr::from_rc_fixedarray(rc_lhs)
  let rhs_ptr = Ptr::from_rc_fixedarray(rc_rhs)
  let cmp = memcmp(
    lhs_ptr.reinterpret_as_const_byte_ptr(),
    rhs_ptr.reinterpret_as_const_byte_ptr(),
    (4L * size_of_double).reinterpret_as_uint64(),
  )
  try_finally(() => assert_eq(cmp, 0), finally_=fn() {
    rc_lhs.release()
    rc_rhs.release()
  })
}

///|
test "is_null" {
  let ptr : Ptr[Int16] = null_pointer |> unsafe_coerce
  assert_eq(ptr.is_null(), true)
}
