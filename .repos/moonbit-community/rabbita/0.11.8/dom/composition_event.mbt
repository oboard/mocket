///|
/// https://developer.mozilla.org/en-US/docs/Web/API/CompositionEvent
#cfg(target="js")
type CompositionEvent

///|
#cfg(target="js")
pub impl IsEvent for CompositionEvent

///|
#cfg(target="js")
pub impl IsUIEvent for CompositionEvent

///|
#cfg(target="js")
pub impl @js.Cast for CompositionEvent with into(value) {
  value |> ffi_to_composition_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for CompositionEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn CompositionEvent::new() -> CompositionEvent = "() => new CompositionEvent()"

///|
#cfg(target="js")
pub extern "js" fn CompositionEvent::get_data(self : Self) -> String = "(e) => e.data"
