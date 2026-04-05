///|
/// https://developer.mozilla.org/en-US/docs/Web/API/SVGGraphicsElement
#cfg(target="js")
type SVGGraphicsElement

///|
#cfg(target="js")
pub impl IsEventTarget for SVGGraphicsElement

///|
#cfg(target="js")
pub impl IsNode for SVGGraphicsElement

///|
#cfg(target="js")
pub impl IsElement for SVGGraphicsElement

///|
#cfg(target="js")
pub impl IsSVGElement for SVGGraphicsElement

///|
#cfg(target="js")
pub impl IsSVGGraphicsElement for SVGGraphicsElement

///|
#cfg(target="js")
pub trait IsSVGGraphicsElement: IsSVGElement {
  as_svg_graphics_element(Self) -> SVGGraphicsElement = _
  get_required_extensions(Self) -> String = _
  get_system_language(Self) -> SVGStringList = _
  get_transform(Self) -> SVGAnimatedTransformList = _
  get_bbox(Self) -> DOMRect = _
  get_ctm(Self) -> DOMMatrix = _
  get_screen_ctm(Self) -> DOMMatrix = _
}

///|
#cfg(target="js")
pub impl @js.Cast for SVGGraphicsElement with into(value) {
  value |> ffi_to_svg_graphics_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for SVGGraphicsElement with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
type SVGStringList

///|
#cfg(target="js")
type SVGAnimatedTransformList

///|
#cfg(target="js")
type DOMMatrix

///|
#cfg(target="js")
impl IsSVGGraphicsElement with as_svg_graphics_element(s) {
  s |> js_identity
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_required_extensions(s) {
  s |> js_identity |> ffi_get_required_extensions
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_system_language(s) {
  s |> js_identity |> ffi_get_system_language
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_transform(s) {
  s |> js_identity |> ffi_get_transform
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_bbox(s) {
  s |> js_identity |> ffi_get_bbox
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_ctm(s) {
  s |> js_identity |> ffi_get_ctm
}

///|
#cfg(target="js")
impl IsSVGGraphicsElement with get_screen_ctm(s) {
  s |> js_identity |> ffi_get_screen_ctm
}

///|
#cfg(target="js")
extern "js" fn ffi_get_required_extensions(s : @js.Value) -> String = "(self) => self.requiredExtensions"

///|
#cfg(target="js")
extern "js" fn ffi_get_system_language(s : @js.Value) -> SVGStringList = "(self) => self.systemLanguage"

///|
#cfg(target="js")
extern "js" fn ffi_get_transform(s : @js.Value) -> SVGAnimatedTransformList = "(self) => self.transform"

///|
#cfg(target="js")
extern "js" fn ffi_get_bbox(s : @js.Value) -> DOMRect = "(self) => self.getBBox()"

///|
#cfg(target="js")
extern "js" fn ffi_get_ctm(s : @js.Value) -> DOMMatrix = "(self) => self.getCTM()"

///|
#cfg(target="js")
extern "js" fn ffi_get_screen_ctm(s : @js.Value) -> DOMMatrix = "(self) => self.getScreenCTM()"
