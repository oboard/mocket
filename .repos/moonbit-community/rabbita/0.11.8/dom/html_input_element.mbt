///|
#cfg(target="js")
#external
type HTMLInputElement

///|
#cfg(target="js")
pub impl IsEventTarget for HTMLInputElement

///|
#cfg(target="js")
pub impl @js.Cast for HTMLInputElement with into(value) {
  value |> ffi_to_html_input_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for HTMLInputElement with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsNode for HTMLInputElement

///|
#cfg(target="js")
pub impl IsElement for HTMLInputElement

///|
#cfg(target="js")
pub impl IsHtmlElement for HTMLInputElement

///|
#cfg(target="js")
pub extern "js" fn HTMLInputElement::value(self : Self) -> String = "(self) => self.value"
