///|
pub struct Object(Value)

///|
pub extern "js" fn Object::new() -> Object = "() => new Object()"

///|
pub fn Object::from_value_unchecked(value : Value) -> Object {
  value
}

///|
pub fn Object::to_value(self : Object) -> Value {
  self.0
}

///|
pub extern "js" fn Object::from_value(value : Value) -> Optional[Object] =
  #| (value) => (value) instanceof Object ? value : undefined

///|
pub extern "js" fn Object::extend_object(self : Object, obj : Object) -> Object =
  #| (self, obj) => ({ ...self, ...obj })

///|
pub fn[K, V] Object::extend_iter(self : Object, it : Iter[(K, V)]) -> Unit {
  for p in it {
    self[p.0] = p.1
  }
}

///|
pub fn[K, V] Object::from_iter(it : Iter[(K, V)]) -> Object {
  let obj = Object::new()
  obj..extend_iter(it)
  obj
}

///|
pub fn[K, V] Object::extend_iter2(self : Object, it : Iter2[K, V]) -> Unit {
  for k, v in it {
    self[k] = v
  }
}

///|
pub fn[K, V] Object::from_iter2(it : Iter2[K, V]) -> Object {
  let obj = Object::new()
  obj..extend_iter2(it)
  obj
}

///|
pub fn[K, V] Object::op_get(self : Object, key : K) -> V {
  self.0.get_ffi(Value::cast_from(key)).cast()
}

///|
pub fn[K, V] Object::op_set(self : Object, key : K, value : V) -> Unit {
  self.0.set_ffi(Value::cast_from(key), Value::cast_from(value))
}
