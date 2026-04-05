///|
/// https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent
#cfg(target="js")
type CustomEvent

///|
#cfg(target="js")
pub impl IsEvent for CustomEvent

///|
#cfg(target="js")
pub impl @js.Cast for CustomEvent with into(value) {
  value |> ffi_to_custom_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for CustomEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn CustomEvent::new(
  type_ : String,
  detail? : @js.Optional[@js.Value] = @js.Optional::undefined(),
) -> CustomEvent = "(type, detail) => new CustomEvent(type, { detail: detail })"

///|
#cfg(target="js")
pub extern "js" fn CustomEvent::get_detail(self : Self) -> @js.Value = "(e) => e.detail"
