///|
#cfg(target="js")
#external
type DocumentFragment

///|
#cfg(target="js")
pub impl @js.Cast for DocumentFragment with into(value) {
  value |> ffi_to_document_fragment |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for DocumentFragment with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsEventTarget for DocumentFragment

///|
#cfg(target="js")
pub impl IsNode for DocumentFragment

///|
#cfg(target="js")
pub extern "js" fn DocumentFragment::to_node(self : Self) -> Node = "(x) => x"
