///|
#cfg(target="js")
#external
type SVGImageElement

///|
#cfg(target="js")
pub impl IsEventTarget for SVGImageElement

///|
#cfg(target="js")
pub impl IsNode for SVGImageElement

///|
#cfg(target="js")
pub impl IsElement for SVGImageElement

///|
#cfg(target="js")
pub impl IsSVGElement for SVGImageElement

///|
#cfg(target="js")
pub impl @js.Cast for SVGImageElement with into(value) {
  value |> ffi_to_svg_image_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for SVGImageElement with from(value) {
  value |> js_identity
}
