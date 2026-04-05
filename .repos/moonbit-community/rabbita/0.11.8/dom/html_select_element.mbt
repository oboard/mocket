///|
#cfg(target="js")
#external
type HTMLSelectElement

///|
#cfg(target="js")
pub extern "js" fn HTMLSelectElement::value(self : Self) -> String = "(self) => self.value"
