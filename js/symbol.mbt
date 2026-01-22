///|
#external
type Symbol

///|
pub fn Symbol::make() -> Symbol {
  Symbol::make_ffi(Value::undefined()).cast()
}

///|
pub fn Symbol::make_with_string_js(value : String) -> Symbol {
  Symbol::make_ffi(Value::cast_from(value)).cast()
}

///|
pub fn Symbol::make_with_string(value : String) -> Symbol {
  Symbol::make_with_string_js(value)
}

///|
pub fn Symbol::make_with_number(num : Double) -> Symbol {
  Symbol::make_ffi(Value::cast_from(num)).cast()
}

///|
extern "js" fn Symbol::make_ffi(value : Value) -> Value =
  #| (value) => Symbol(value)

///|
extern "js" fn Symbol::iterator_ffi() -> Value =
  #| () => Symbol.iterator

///|
pub let iterator : Symbol = Symbol::iterator_ffi().cast()

///|
extern "js" fn Symbol::async_iterator_ffi() -> Value =
  #| () => Symbol.asyncIterator

///|
pub let async_iterator : Symbol = Symbol::async_iterator_ffi().cast()
