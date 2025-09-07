///|
extern "js" fn require_ffi(path : String) -> Value = "(path) => require(path)"

///|
pub fn require(path : String, keys~ : Array[String] = []) -> Value {
  keys.fold(init=require_ffi(path), (acc, key) => acc.get_ffi(
    Value::cast_from(key),
  ))
}
