///|
/// https://developer.mozilla.org/en-US/docs/Web/API/SVGElement
#cfg(target="js")
type SVGElement

///|
#cfg(target="js")
pub impl IsEventTarget for SVGElement

///|
#cfg(target="js")
pub impl IsNode for SVGElement

///|
#cfg(target="js")
pub impl IsElement for SVGElement

///|
#cfg(target="js")
pub impl IsSVGElement for SVGElement

///|
#cfg(target="js")
type StylePropertyMap

///|
#cfg(target="js")
type DOMStringMap

///|
#cfg(target="js")
pub trait IsSVGElement: IsElement {
  as_svg_element(Self) -> SVGElement = _
  get_attribute_style_map(Self) -> StylePropertyMap = _
  get_auto_focus(Self) -> Bool = _
  set_auto_focus(Self, Bool) -> Unit = _
  get_data_set(Self) -> DOMStringMap = _
  get_nonce(Self) -> String = _
  set_nonce(Self, String) -> Unit = _
  get_owner_svg_element(Self) -> SVGElement? = _
  get_style(Self) -> CSSStyleDeclaration = _
  set_style(Self, CSSStyleDeclaration) -> Unit = _
  get_tab_index(Self) -> Int = _
  set_tab_index(Self, Int) -> Unit = _
  get_viewport_element(Self) -> SVGElement? = _
  blur(Self) -> Unit = _
  focus(Self) -> Unit = _
}

///|
#cfg(target="js")
pub impl @js.Cast for SVGElement with into(value) {
  value |> ffi_to_svg_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for SVGElement with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
impl IsSVGElement with as_svg_element(s) {
  s |> js_identity
}

///|
#cfg(target="js")
impl IsSVGElement with get_attribute_style_map(s) {
  s |> js_identity |> ffi_get_attribute_style_map
}

///|
#cfg(target="js")
impl IsSVGElement with get_auto_focus(s) {
  s |> js_identity |> get_auto_focus
}

///|
#cfg(target="js")
impl IsSVGElement with set_auto_focus(s, value) {
  s |> js_identity |> set_auto_focus(value)
}

///|
#cfg(target="js")
impl IsSVGElement with get_data_set(s) {
  s |> js_identity |> get_data_set
}

///|
#cfg(target="js")
impl IsSVGElement with get_nonce(s) {
  s |> js_identity |> get_nonce
}

///|
#cfg(target="js")
impl IsSVGElement with set_nonce(s, value) {
  s |> js_identity |> set_nonce(value)
}

///|
#cfg(target="js")
impl IsSVGElement with get_owner_svg_element(s) {
  s |> js_identity |> get_owner_svg_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
impl IsSVGElement with get_style(s) {
  s |> js_identity |> get_style
}

///|
#cfg(target="js")
impl IsSVGElement with set_style(s, style) {
  s |> js_identity |> set_style(style)
}

///|
#cfg(target="js")
impl IsSVGElement with get_tab_index(s) {
  s |> js_identity |> get_tab_index
}

///|
#cfg(target="js")
impl IsSVGElement with set_tab_index(s, value) {
  s |> js_identity |> set_tab_index(value)
}

///|
#cfg(target="js")
impl IsSVGElement with get_viewport_element(s) {
  s |> js_identity |> get_viewport_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
impl IsSVGElement with blur(s) {
  s |> js_identity |> blur
}

///|
#cfg(target="js")
impl IsSVGElement with focus(s) {
  s |> js_identity |> focus
}

///|
#cfg(target="js")
extern "js" fn ffi_get_attribute_style_map(x : @js.Value) -> StylePropertyMap = "(self) => self.style"

///|
#cfg(target="js")
extern "js" fn get_auto_focus(x : @js.Value) -> Bool = "(self) => self.autofocus"

///|
#cfg(target="js")
extern "js" fn set_auto_focus(x : @js.Value, value : Bool) = "(self, value) => self.autofocus = value"

///|
#cfg(target="js")
extern "js" fn get_data_set(x : @js.Value) -> DOMStringMap = "(self) => self.dataset"

///|
#cfg(target="js")
extern "js" fn get_nonce(x : @js.Value) -> String = "(self) => self.nonce"

///|
#cfg(target="js")
extern "js" fn set_nonce(x : @js.Value, value : String) = "(self, value) => self.nonce = value"

///|
#cfg(target="js")
extern "js" fn get_owner_svg_element(x : @js.Value) -> @js.Optional[SVGElement] = "(self) => self.ownerSVGElement"

///|
#cfg(target="js")
extern "js" fn get_style(x : @js.Value) -> CSSStyleDeclaration = "(self) => self.style"

///|
#cfg(target="js")
extern "js" fn set_style(x : @js.Value, style : CSSStyleDeclaration) = "(self, style) => self.style = style"

///|
#cfg(target="js")
extern "js" fn get_tab_index(x : @js.Value) -> Int = "(self) => self.tabIndex"

///|
#cfg(target="js")
extern "js" fn set_tab_index(x : @js.Value, value : Int) = "(self, value) => self.tabIndex = value"

///|
#cfg(target="js")
extern "js" fn get_viewport_element(x : @js.Value) -> @js.Optional[SVGElement] = "(self) => self.viewportElement"

///|
#cfg(target="js")
extern "js" fn blur(x : @js.Value) = "(self) => self.blur()"

///|
#cfg(target="js")
extern "js" fn focus(x : @js.Value) = "(self) => self.focus()"
