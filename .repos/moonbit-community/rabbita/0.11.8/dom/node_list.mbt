///|
/// https://developer.mozilla.org/en-US/docs/Web/API/NodeList
#cfg(target="js")
#external
type NodeList

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/NodeList/length
#cfg(target="js")
pub extern "js" fn NodeList::get_length(self : Self) -> Double = "(self) => self.length"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/NodeList/item
#cfg(target="js")
pub extern "js" fn NodeList::item(
  self : Self,
  index : Double,
) -> @js.Nullable[Node] = "(self,index) => self.item(index)"

// TODO: Support other methods that return an iterator.
