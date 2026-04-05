///|
#cfg(target="js")
#external
type ImageBitmap

///|
#cfg(target="js")
pub impl @js.Cast for ImageBitmap with into(value) {
  value |> ffi_to_image_bitmap |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for ImageBitmap with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
extern "js" fn ffi_to_image_bitmap(
  value : @js.Value,
) -> @js.Nullable[ImageBitmap] = "(value) => value instanceof ImageBitmap ? value : null"
