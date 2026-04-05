///|
#cfg(target="js")
#external
type Text

///|
#cfg(target="js")
pub impl @js.Cast for Text with into(value) {
  value |> ffi_to_text |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for Text with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsEventTarget for Text

///|
#cfg(target="js")
pub impl IsNode for Text

///|
#cfg(target="js")
pub extern "js" fn Text::to_node(self : Self) -> Node = "(x) => x"
