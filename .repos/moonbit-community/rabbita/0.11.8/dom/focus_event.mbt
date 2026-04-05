///|
#cfg(target="js")
#external
type FocusEvent

///|
#cfg(target="js")
pub impl IsEvent for FocusEvent

///|
#cfg(target="js")
pub impl IsUIEvent for FocusEvent

///|
#cfg(target="js")
pub impl @js.Cast for FocusEvent with into(value) {
  value |> ffi_to_focus_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for FocusEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn FocusEvent::related_target(self : Self) -> EventTarget = "(e) => e.relatedTarget"
