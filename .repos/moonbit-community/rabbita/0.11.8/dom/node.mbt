///|
#cfg(target="js")
#external
type Node

///|
#cfg(target="js")
pub trait IsNode: IsEventTarget {
  as_node(Self) -> Node = _
  get_node_type(Self) -> Int = _
  get_node_name(Self) -> String = _
  get_node_value(Self) -> String = _
  set_node_value(Self, @js.Nullable[String]) -> Unit = _
  get_first_child(Self) -> Node = _
  get_last_child(Self) -> Node = _
  get_next_sibling(Self) -> @js.Nullable[Node] = _
  get_previous_sibling(Self) -> @js.Nullable[Node] = _
  get_parent_node(Self) -> @js.Nullable[Node] = _
  append_child(Self, Node) -> Unit = _
  remove_child(Self, Node) -> Unit = _
  replace_child(Self, Node, Node) -> Unit = _
  insert_before(Self, Node, @js.Nullable[Node]) -> Unit = _
  get_child(Self, Int) -> Node = _
  get_child_count(Self) -> Int = _
  is_same_node(Self, Node) -> Bool = _
}

///|
#cfg(target="js")
pub impl IsEventTarget for Node

///|
#cfg(target="js")
pub impl @js.Cast for Node with into(value) {
  value |> ffi_to_node |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for Node with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsNode for Node

///|
#cfg(target="js")
impl IsNode with set_node_value(s, v) {
  ffi_set_node_value(js_identity(s), v)
}

///|
#cfg(target="js")
impl IsNode with as_node(s) {
  js_identity(s)
}

///|
#cfg(target="js")
impl IsNode with get_node_type(s) {
  s |> js_identity |> ffi_node_type
}

///|
#cfg(target="js")
impl IsNode with get_node_name(s) {
  s |> js_identity |> ffi_node_name
}

///|
#cfg(target="js")
impl IsNode with get_node_value(s) {
  s |> js_identity |> ffi_node_value
}

///|
#cfg(target="js")
impl IsNode with get_first_child(s) {
  s |> js_identity |> first_child
}

///|
#cfg(target="js")
impl IsNode with get_last_child(s) {
  s |> js_identity |> ffi_last_child
}

///|
#cfg(target="js")
impl IsNode with get_next_sibling(s) {
  s |> js_identity |> ffi_next_sibling
}

///|
#cfg(target="js")
impl IsNode with get_previous_sibling(s) {
  s |> js_identity |> ffi_previous_sibling
}

///|
#cfg(target="js")
impl IsNode with get_parent_node(s) {
  s |> js_identity |> ffi_parent_node
}

///|
#cfg(target="js")
impl IsNode with append_child(s, child) {
  s |> js_identity |> ffi_append_child(child)
}

///|
#cfg(target="js")
impl IsNode with remove_child(s, child) {
  s |> js_identity |> ffi_remove_child(child)
}

///|
#cfg(target="js")
impl IsNode with replace_child(s, new, old) {
  s |> js_identity |> ffi_replace_child(new, old)
}

///|
#cfg(target="js")
impl IsNode with insert_before(s, value, before) {
  s |> js_identity |> insert_before(value, before)
}

///|
#cfg(target="js")
impl IsNode with get_child(s, index) {
  s |> js_identity |> ffi_nth_child(index)
}

///|
#cfg(target="js")
impl IsNode with get_child_count(s) {
  s |> js_identity |> ffi_count_child
}

///|
#cfg(target="js")
impl IsNode with is_same_node(s, other) {
  s |> js_identity |> ffi_is_same_node(other)
}

// ---------- node API --------------

///|
#cfg(target="js")
extern "js" fn ffi_node_type(x : @js.Value) -> Int = "(x) => x.nodeType"

///|
#cfg(target="js")
extern "js" fn ffi_node_name(x : @js.Value) -> String = "(x) => x.nodeName"

///|
#cfg(target="js")
extern "js" fn ffi_node_value(x : @js.Value) -> String = "(x) => x.nodeValue"

///|
#cfg(target="js")
extern "js" fn first_child(x : @js.Value) -> Node = "(x) => x.firstChild"

///|
#cfg(target="js")
extern "js" fn ffi_last_child(x : @js.Value) -> Node = "(x) => x.lastChild"

///|
#cfg(target="js")
extern "js" fn ffi_next_sibling(x : @js.Value) -> @js.Nullable[Node] = "(x) => x.nextSibling"

///|
#cfg(target="js")
extern "js" fn ffi_previous_sibling(x : @js.Value) -> @js.Nullable[Node] = "(x) => x.previousSibling"

///|
#cfg(target="js")
extern "js" fn ffi_parent_node(x : @js.Value) -> @js.Nullable[Node] = "(x) => x.parentNode"

///|
#cfg(target="js")
extern "js" fn ffi_append_child(x : @js.Value, child : Node) = "(p,c) => p.appendChild(c)"

///|
#cfg(target="js")
extern "js" fn ffi_remove_child(x : @js.Value, child : Node) = "(p,c) => p.removeChild(c)"

///|
#cfg(target="js")
extern "js" fn ffi_replace_child(x : @js.Value, new : Node, old : Node) = "(p,n,o) => p.replaceChild(n,o)"

///|
#cfg(target="js")
extern "js" fn insert_before(
  x : @js.Value,
  value : Node,
  before : @js.Nullable[Node],
) = "(p,value,before) => p.insertBefore(value,before)"

// ---------- some specific node API --------------
// Note: the childNodes property is a NodeList, not an array, so we can't use the Array type.

///|
#cfg(target="js")
extern "js" fn ffi_nth_child(x : @js.Value, index : Int) -> Node =
  #| (x,i) => { 
  #|   const r = x.childNodes[i]; 
  #|   if (r === undefined) throw new Error(`nth_child: index ${i} out of bounds, length=${x.childNodes.length}`);
  #|   return r;
  #| }

///|
#cfg(target="js")
extern "js" fn ffi_count_child(x : @js.Value) -> Int = "(x) => x.childNodes.length"

///|
#cfg(target="js")
extern "js" fn ffi_set_node_value(x : @js.Value, v : @js.Nullable[String]) = "(x,v) => x.nodeValue = v"

///|
#cfg(target="js")
extern "js" fn ffi_is_same_node(x : @js.Value, other : Node) -> Bool = "(x, other) => x === other"
