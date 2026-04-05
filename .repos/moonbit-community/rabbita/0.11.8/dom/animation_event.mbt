///|
/// https://developer.mozilla.org/en-US/docs/Web/API/AnimationEvent
#cfg(target="js")
type AnimationEvent

///|
#cfg(target="js")
pub impl IsEvent for AnimationEvent

///|
#cfg(target="js")
pub impl @js.Cast for AnimationEvent with into(value) {
  value |> ffi_to_animation_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for AnimationEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn AnimationEvent::get_animation_name(self : Self) -> String = "(e) => e.animationName"

///|
#cfg(target="js")
pub extern "js" fn AnimationEvent::get_elapsed_time(self : Self) -> Double = "(e) => e.elapsedTime"

///|
#cfg(target="js")
pub extern "js" fn AnimationEvent::get_pseudo_element(self : Self) -> String = "(e) => e.pseudoElement"
