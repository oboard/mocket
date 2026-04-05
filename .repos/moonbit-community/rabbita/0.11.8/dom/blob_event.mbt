///|
/// https://developer.mozilla.org/en-US/docs/Web/API/BlobEvent
#cfg(target="js")
type BlobEvent

///|
#cfg(target="js")
pub impl IsEvent for BlobEvent

///|
#cfg(target="js")
pub impl @js.Cast for BlobEvent with into(value) {
  value |> ffi_to_blob_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for BlobEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn BlobEvent::new() -> BlobEvent = "() => new BlobEvent()"

///|
#cfg(target="js")
pub extern "js" fn BlobEvent::get_data(self : Self) -> Blob = "(e) => e.data"

///|
#cfg(target="js")
pub extern "js" fn BlobEvent::get_timecode(self : Self) -> DOMHighResTimeStamp = "(e) => e.timecode"
