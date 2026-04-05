///|
/// https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent
#cfg(target="js")
type CloseEvent

///|
#cfg(target="js")
pub impl IsEvent for CloseEvent

///|
#cfg(target="js")
pub impl @js.Cast for CloseEvent with into(value) {
  value |> ffi_to_close_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for CloseEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn CloseEvent::get_code(self : Self) -> Int = "(e) => e.code"

///|
#cfg(target="js")
pub extern "js" fn CloseEvent::get_reason(self : Self) -> String = "(e) => e.reason"

///|
#cfg(target="js")
pub extern "js" fn CloseEvent::get_was_clean(self : Self) -> Bool = "(e) => e.wasClean"
