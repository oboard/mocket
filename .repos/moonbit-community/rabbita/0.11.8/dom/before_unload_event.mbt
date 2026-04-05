///|
/// https://developer.mozilla.org/en-US/docs/Web/API/BeforeUnloadEvent
#cfg(target="js")
type BeforeUnloadEvent

///|
#cfg(target="js")
pub impl IsEvent for BeforeUnloadEvent

///|
#cfg(target="js")
pub impl @js.Cast for BeforeUnloadEvent with into(value) {
  value |> ffi_to_before_unload_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for BeforeUnloadEvent with from(value) {
  value |> js_identity
}
