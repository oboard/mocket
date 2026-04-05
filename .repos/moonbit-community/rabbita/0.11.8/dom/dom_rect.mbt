///|
#cfg(target="js")
#external
type DOMRect

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_x(self : Self) -> Double = "(self) => self.x"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_y(self : Self) -> Double = "(self) => self.y"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_width(self : Self) -> Double = "(self) => self.width"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_height(self : Self) -> Double = "(self) => self.height"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_top(self : Self) -> Double = "(self) => self.top"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_right(self : Self) -> Double = "(self) => self.right"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_bottom(self : Self) -> Double = "(self) => self.bottom"

///|
#cfg(target="js")
pub extern "js" fn DOMRect::get_left(self : Self) -> Double = "(self) => self.left"
