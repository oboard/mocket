///|
#external
pub type Value

///|
pub fn[T] Value::cast_from(value : T) -> Value = "%identity"

///|
pub fn[T] Value::cast(self : Value) -> T = "%identity"

///|
#borrow(self)
pub extern "js" fn Value::to_string(self : Value) -> String = "(self) => self.toString()"

///|
pub impl Show for Value with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub let globalThis : Value = get_globalThis()

///|
pub fn[T] Value::get_with_string(self : Value, key : String) -> T {
  self.get_ffi(Value::cast_from(key)).cast()
}

///|
pub fn[T] Value::get_with_symbol(self : Value, key : Symbol) -> T {
  self.get_ffi(Value::cast_from(key)).cast()
}

///|
pub fn[T] Value::get_with_index(self : Value, index : Int) -> T {
  self.get_ffi(Value::cast_from(index)).cast()
}

///|
pub fn[T] Value::set_with_string(self : Value, key : String, value : T) -> Unit {
  self.set_ffi(Value::cast_from(key), Value::cast_from(value))
}

///|
pub fn[T] Value::set_with_symbol(self : Value, key : Symbol, value : T) -> Unit {
  self.set_ffi(Value::cast_from(key), Value::cast_from(value))
}

///|
pub fn[T] Value::set_with_index(self : Value, index : Int, value : T) -> Unit {
  self.set_ffi(Value::cast_from(index), Value::cast_from(value))
}

///|
/// `self(...args)`
pub fn[Arg, Result] Value::apply(self : Value, args : Array[Arg]) -> Result {
  self.apply_self_ffi(Value::cast_from(args)).cast()
}

///|
/// `self[key](...args)`
pub fn[Arg, Result] Value::apply_with_string(
  self : Value,
  key : String,
  args : Array[Arg],
) -> Result {
  self.apply_ffi(Value::cast_from(key), Value::cast_from(args)).cast()
}

///|
/// `self[key](...args)`
pub fn[Arg, Result] Value::apply_with_symbol(
  self : Value,
  key : Symbol,
  args : Array[Arg],
) -> Result {
  self.apply_ffi(Value::cast_from(key), Value::cast_from(args)).cast()
}

///|
/// `self[index](...args)`
pub fn[Arg, Result] Value::apply_with_index(
  self : Value,
  index : Int,
  args : Array[Arg],
) -> Result {
  self.apply_ffi(Value::cast_from(index), Value::cast_from(args)).cast()
}

///|
/// `new self(...args)`
pub fn[Arg, Result] Value::new(self : Value, args : Array[Arg]) -> Result {
  self.new_self_ffi(Value::cast_from(args)).cast()
}

///|
/// `new self[key](...args)`
pub fn[Arg, Result] Value::new_with_string(
  self : Value,
  key : String,
  args : Array[Arg],
) -> Result {
  self.new_ffi(Value::cast_from(key), Value::cast_from(args)).cast()
}

///|
/// `new self[key](...args)`
pub fn[Arg, Result] Value::new_with_symbol(
  self : Value,
  key : Symbol,
  args : Array[Arg],
) -> Result {
  self.new_ffi(Value::cast_from(key), Value::cast_from(args)).cast()
}

///|
/// `new self[index](...args)`
pub fn[Arg, Result] Value::new_with_index(
  self : Value,
  index : Int,
  args : Array[Arg],
) -> Result {
  self.new_ffi(Value::cast_from(index), Value::cast_from(args)).cast()
}

///|
pub fn Value::from_json(json : Json) -> Value raise {
  @json.from_json(json)
}

///|
pub impl @json.FromJson for Value with fn from_json(json : Json, path) {
  match json {
    String(s) => Value::cast_from(s)
    Number(n, ..) => Value::cast_from(n)
    False => Value::cast_from(false)
    True => Value::cast_from(true)
    Null => Value::null()
    Array(xs) => {
      let acc = Array::new(capacity=xs.length())
      for x in xs {
        acc.push((@json.from_json(x, path~) : Value))
      }
      Value::cast_from(acc)
    }
    Object(kvs) => {
      let acc = Object::new()
      for k, v in kvs {
        acc.0.set_with_string(k, (@json.from_json(v, path~) : Value))
      }
      acc.0
    }
  }
}

///|
pub fn Value::from_json_string(str : String) -> Value raise {
  Error_::wrap(() => Value::from_json_string_ffi(str))
}

///|
#borrow(str)
extern "js" fn Value::from_json_string_ffi(str : String) -> Value = "JSON.parse"

///|
pub fn Value::to_json_string(self : Value) -> String raise {
  Error_::wrap(() => self.to_json_string_ffi())
}

///|
pub fn Value::to_json(self : Value) -> Json raise {
  @json.parse(self.to_json_string())
}

///|
#borrow(self)
extern "js" fn Value::to_json_string_ffi(self : Value) -> Value =
  #| (self) => JSON.stringify(self)

///|
#borrow(self)
pub extern "js" fn Value::is_bool(self : Value) -> Bool =
  #| (value) => Object.is(typeof value, 'boolean')

///|
#borrow(self)
pub extern "js" fn Value::is_null(self : Value) -> Bool =
  #| (n) => Object.is(n, null)

///|
#borrow(self)
pub extern "js" fn Value::is_undefined(self : Value) -> Bool =
  #| (n) => Object.is(n, undefined)

///|
#borrow(self)
pub extern "js" fn Value::is_number(self : Value) -> Bool =
  #| (n) => Object.is(typeof n, "number")

///|
#borrow(self)
pub extern "js" fn Value::is_string(self : Value) -> Bool =
  #| (n) => Object.is(typeof n, "string")

///|
#borrow(self)
pub extern "js" fn Value::is_object(self : Value) -> Bool =
  #| (n) => Object.is(typeof n, "object")

///|
#borrow(self)
pub extern "js" fn Value::is_symbol(self : Value) -> Bool =
  #| (n) => Object.is(typeof n, "symbol")

///|
extern "js" fn get_globalThis() -> Value =
  #| () => globalThis

///|
#borrow(self, key)
extern "js" fn Value::get_ffi(self : Value, key : Value) -> Value =
  #| (obj, key) => obj[key]

///|
#borrow(self, key, value)
extern "js" fn Value::set_ffi(self : Value, key : Value, value : Value) =
  #| (obj, key, value) => { obj[key] = value }

///|
#borrow(self, key, args)
extern "js" fn Value::apply_ffi(
  self : Value,
  key : Value,
  args : Value,
) -> Value =
  #| (self, key, args) => self[key](...args)

///|
#borrow(self, args)
extern "js" fn Value::apply_self_ffi(self : Value, args : Value) -> Value =
  #| (self, args) => self(...args)

///|
#borrow(self, key, args)
extern "js" fn Value::new_ffi(self : Value, key : Value, args : Value) -> Value =
  #| (self, key, args) => new self[key](...args)

///|
#borrow(self, args)
extern "js" fn Value::new_self_ffi(self : Value, args : Value) -> Value =
  #| (self, args) => new self(...args)

///|
extern "js" fn Value::null() -> Value =
  #| () => null

///|
extern "js" fn Value::undefined() -> Value =
  #| () => undefined

///|
/// @param self The constructor function that accepts this as the first argument
#borrow(self, parent_constructor)
pub extern "js" fn Value::extends(
  self : Value,
  parent_constructor : Value,
) -> Value =
  #|(f, parent) => {
  #|  return class extends parent {
  #|    constructor(...args) {
  #|      super();
  #|      f(this, ...args);
  #|    }
  #|  }
  #|}
