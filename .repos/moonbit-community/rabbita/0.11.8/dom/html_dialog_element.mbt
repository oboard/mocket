///|
#cfg(target="js")
#external
type HTMLDialogElement

///|
#cfg(target="js")
pub impl IsEventTarget for HTMLDialogElement

///|
#cfg(target="js")
pub impl @js.Cast for HTMLDialogElement with into(value) {
  value |> ffi_to_html_dialog_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for HTMLDialogElement with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsNode for HTMLDialogElement

///|
#cfg(target="js")
pub impl IsElement for HTMLDialogElement

///|
#cfg(target="js")
pub impl IsHtmlElement for HTMLDialogElement

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::open(self : Self) -> Bool = "(self) => self.open"

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::return_value(self : Self) -> String = "(self) => self.returnValue"

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::close(
  self : Self,
  return_value? : @js.Optional[String] = @js.Optional::undefined(),
) = "(self,returnValue) => self.close(returnValue)"

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::request_close(
  self : Self,
  return_value? : @js.Optional[String] = @js.Optional::undefined(),
) = "(self, returnValue) => self.requestClose(returnValue)"

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::show(self : Self) = "(self) => self.show()"

///|
#cfg(target="js")
pub extern "js" fn HTMLDialogElement::show_modal(self : Self) = "(self) => self.showModal()"
