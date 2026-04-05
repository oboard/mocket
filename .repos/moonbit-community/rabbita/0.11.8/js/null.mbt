///|
#cfg(target="js")
#external
type Nullable[_]

///|
#cfg(target="js")
pub fn[T] Nullable::is_null(self : Nullable[T]) -> Bool {
  Value::is_null(Value::cast_from(self))
}

///|
#cfg(target="js")
#deprecated("get_exn does not check for null values. Use unwrap instead", skip_current_package=true)
pub fn[T] Nullable::get_exn(self : Nullable[T]) -> T = "%identity"

///|
/// Unwraps the nullable value, panicking if it is null.
#cfg(target="js")
pub fn[T] Nullable::unwrap(self : Nullable[T]) -> T {
  if self.is_null() {
    abort("Cannot unwrap a null value")
  }
  self.get_exn()
}

///|
#cfg(target="js")
pub fn[T] Nullable::to_option(self : Nullable[T]) -> T? {
  guard !Value::cast_from(self).is_null() else { None }
  Some(self.unwrap())
}

///|
#cfg(target="js")
pub fn[T] Nullable::null() -> Nullable[T] {
  Value::null().cast()
}

///|
#cfg(target="js")
pub fn[T] Nullable::from_option(value : T?) -> Nullable[T] {
  value.map(Value::cast_from).unwrap_or_else(Value::null).cast()
}
