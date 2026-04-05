///|
#cfg(target="js")
#external
type ClipboardEvent

///|
#cfg(target="js")
pub impl IsEvent for ClipboardEvent

///|
#cfg(target="js")
pub impl @js.Cast for ClipboardEvent with into(value) {
  value |> ffi_to_clipboard_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for ClipboardEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn ClipboardEvent::clipboard_data(self : Self) -> DataTransfer = "(e) => e.clipboardData"
