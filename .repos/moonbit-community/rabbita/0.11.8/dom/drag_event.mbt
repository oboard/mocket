///|
#cfg(target="js")
type DragEvent

///|
#cfg(target="js")
pub impl IsEvent for DragEvent

///|
#cfg(target="js")
pub impl IsUIEvent for DragEvent

///|
#cfg(target="js")
pub impl IsMouseEvent for DragEvent

///|
#cfg(target="js")
pub impl @js.Cast for DragEvent with into(value) {
  value |> ffi_to_drag_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for DragEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn DragEvent::get_data_transfer(self : Self) -> DataTransfer = "(e) => e.dataTransfer"
