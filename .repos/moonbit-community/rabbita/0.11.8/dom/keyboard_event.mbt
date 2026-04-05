///|
#cfg(target="js")
#external
type KeyboardEvent

///|
#cfg(target="js")
pub impl IsEvent for KeyboardEvent

///|
#cfg(target="js")
pub impl IsUIEvent for KeyboardEvent

///|
#cfg(target="js")
pub impl @js.Cast for KeyboardEvent with into(value) {
  value |> ffi_to_keyboard_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for KeyboardEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::key(self : Self) -> String = "(e) => e.key"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::code(self : Self) -> String = "(e) => e.code"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::alt_key(self : Self) -> Bool = "(e) => e.altKey"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::ctrl_key(self : Self) -> Bool = "(e) => e.ctrlKey"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::shift_key(self : Self) -> Bool = "(e) => e.shiftKey"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::meta_key(self : Self) -> Bool = "(e) => e.metaKey"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::is_composing(self : Self) -> Bool = "(e) => e.isComposing"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::repeat(self : Self) -> Bool = "(e) => e.repeat"

///|
#cfg(target="js")
pub extern "js" fn KeyboardEvent::location(self : Self) -> Int = "(e) => e.location"

///|
#cfg(target="js")
pub const DOM_KEY_LOCATION_STANDARD : Int = 0x00

///|
#cfg(target="js")
pub const DOM_KEY_LOCATION_LEFT : Int = 0x01

///|
#cfg(target="js")
pub const DOM_KEY_LOCATION_RIGHT : Int = 0x02

///|
#cfg(target="js")
pub const DOM_KEY_LOCATION_NUMPAD : Int = 0x03
