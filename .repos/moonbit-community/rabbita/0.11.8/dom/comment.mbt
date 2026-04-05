///|
#cfg(target="js")
#external
type Comment

///|
#cfg(target="js")
pub impl @js.Cast for Comment with into(value) {
  value |> ffi_to_comment |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for Comment with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsEventTarget for Comment

///|
#cfg(target="js")
pub impl IsNode for Comment

///|
#cfg(target="js")
pub extern "js" fn Comment::to_node(self : Self) -> Node = "(x) => x"
