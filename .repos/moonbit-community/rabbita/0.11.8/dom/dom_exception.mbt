///|
#cfg(target="js")
#external
type DOMException

///|
#cfg(target="js")
pub extern "js" fn DOMException::get_message(self : Self) -> String = "(self) => self.message"

///|
#cfg(target="js")
pub extern "js" fn DOMException::get_name(self : Self) -> String = "(self) => self.name"

///|
#cfg(target="js")
pub extern "js" fn DOMException::new() -> DOMException = "() => new DOMException()"

///|
#cfg(target="js")
pub extern "js" fn DOMException::new_with_message(
  message : String,
) -> DOMException = "(message) => new DOMException(message)"

///|
#cfg(target="js")
pub extern "js" fn DOMException::new_with_message_and_name(
  message : String,
  name : String,
) -> DOMException = "(message,name) => new DOMException(message, name)"
