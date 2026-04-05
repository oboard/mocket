///|
#cfg(target="js")
type WheelEvent

///|
#cfg(target="js")
pub impl IsEvent for WheelEvent

///|
#cfg(target="js")
pub impl IsUIEvent for WheelEvent

///|
#cfg(target="js")
pub impl IsMouseEvent for WheelEvent

///|
#cfg(target="js")
pub impl @js.Cast for WheelEvent with into(value) {
  value |> ffi_to_wheel_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for WheelEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn WheelEvent::get_delta_x(self : Self) -> Double = "(e) => e.deltaX"

///|
#cfg(target="js")
pub extern "js" fn WheelEvent::get_delta_y(self : Self) -> Double = "(e) => e.deltaY"

///|
#cfg(target="js")
pub extern "js" fn WheelEvent::get_delta_z(self : Self) -> Double = "(e) => e.deltaZ"

///|
#cfg(target="js")
pub extern "js" fn WheelEvent::get_delta_mode(self : Self) -> Int = "(e) => e.deltaMode"
