///| Performs a checked cast from a `Value` to a `Self?` type.
/// 
/// This trait abstracts a function that ensures the cast is valid and returns `null` if the cast fails.
/// It is useful for safely handling dynamic types in MoonBit.
pub(open) trait Cast {
  into(Value) -> Self?
  from(Self) -> Value
}

// NOTE: Do we need a default implementation for the `from` method in `Cast` trait?
// 
// If the type `Self` can be cast from a `Value`, then it must can be cast back to a `Value` safely,
// only when the `Self` type is a abstract type that represents a JavaScript type.
//
// ```
// impl Cast with from(self) { Value::cast_from(self) }
// ```
//
// But if some one implements the `Cast` trait for a type that not an abstract type, 
// then the default implementation is not type-safe.

///|
extern "js" fn checked_cast_string_ffi(value : Value) -> Nullable[String] =
  #| (x) => typeof x === 'string' ? x : null

///|
extern "js" fn checked_cast_int_ffi(value : Value) -> Nullable[Int] =
  #| (x) => typeof x === 'number' && Number.isInteger(x) ? x : null

///|
extern "js" fn checked_cast_double_ffi(value : Value) -> Nullable[Double] =
  #| (x) => typeof x === 'number' ? x : null

///|
extern "js" fn checked_cast_bool_ffi(value : Value) -> Nullable[Bool] =
  #| (x) => typeof x === 'boolean' ? x : null

///|
extern "js" fn checked_cast_array_ffi(value : Value) -> Nullable[Array[Value]] =
  #| (x) => Array.isArray(x) ? x : null

///|
pub impl Cast for String with into(value) {
  checked_cast_string_ffi(value).to_option()
}

///|
pub impl Cast for String with from(value) {
  Value::cast_from(value)
}

///|
pub impl Cast for Int with into(value) {
  checked_cast_int_ffi(value).to_option()
}

///|
pub impl Cast for Int with from(value) {
  Value::cast_from(value)
}

///|
pub impl Cast for Double with into(value) {
  checked_cast_double_ffi(value).to_option()
}

///|
pub impl Cast for Double with from(value) {
  Value::cast_from(value)
}

///|
pub impl Cast for Bool with into(value) {
  checked_cast_bool_ffi(value).to_option()
}

///|
pub impl Cast for Bool with from(value) {
  Value::cast_from(value)
}

///|
pub impl[A : Cast] Cast for Array[A] with into(value) {
  checked_cast_array_ffi(value)
  .to_option()
  .bind(fn(arr) {
    let is_type_a = fn(elem) { not((Cast::into(elem) : A?).is_empty()) }
    if arr.iter().all(is_type_a) {
      Some(Value::cast_from(arr).cast())
    } else {
      None
    }
  })
}

///|
pub impl[A : Cast] Cast for Array[A] with from(value) {
  Value::cast_from(value)
}
