///|
/// https://developer.mozilla.org/en-US/docs/Web/API/HTMLCollection
#cfg(target="js")
#external
type HTMLCollection

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/HTMLCollection/length
#cfg(target="js")
pub extern "js" fn HTMLCollection::get_length(self : Self) -> Double = "(self) => self.length"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/HTMLCollection/item
#cfg(target="js")
pub extern "js" fn HTMLCollection::item(
  self : Self,
  index : Double,
) -> @js.Nullable[Element] = "(self,index) => self.item(index)"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/HTMLCollection/namedItem
#cfg(target="js")
pub extern "js" fn HTMLCollection::named_item(
  self : Self,
  key : String,
) -> @js.Nullable[Element] = "(self,key) => self.namedItem(key)"
