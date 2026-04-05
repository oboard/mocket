///|
#cfg(target="js")
#external
type Symbol

///|
#cfg(target="js")
pub fn Symbol::make() -> Symbol {
  Symbol::make_ffi(Value::undefined()).cast()
}

///|
#cfg(target="js")
pub fn Symbol::make_with_string_js(value : String) -> Symbol {
  Symbol::make_ffi(Value::cast_from(value)).cast()
}

///|
#cfg(target="js")
pub fn Symbol::make_with_string(value : String) -> Symbol {
  Symbol::make_with_string_js(value)
}

///|
#cfg(target="js")
pub fn Symbol::make_with_number(num : Double) -> Symbol {
  Symbol::make_ffi(Value::cast_from(num)).cast()
}

///|
#cfg(target="js")
extern "js" fn Symbol::make_ffi(value : Value) -> Value =
  #| (value) => Symbol(value)

///|
#cfg(target="js")
extern "js" fn Symbol::iterator_ffi() -> Value =
  #| () => Symbol.iterator

///|
#cfg(target="js")
pub let iterator : Symbol = Symbol::iterator_ffi().cast()

///|
#cfg(target="js")
extern "js" fn Symbol::async_iterator_ffi() -> Value =
  #| () => Symbol.asyncIterator

///|
#cfg(target="js")
pub let async_iterator : Symbol = Symbol::async_iterator_ffi().cast()
