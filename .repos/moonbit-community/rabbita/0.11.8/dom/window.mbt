///|
#cfg(target="js")
type Window

///|
#cfg(target="js")
pub impl IsEventTarget for Window

///|
#cfg(target="js")
pub impl @js.Cast for Window with into(value) {
  value |> ffi_to_window |> x => { x.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for Window with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_to(self : Self, x : Int, y : Int) =
  #| (self, x, y) => { self.scrollTo(x, y); }

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_by(self : Self, x : Int, y : Int) =
  #| (self, x, y) => { self.scrollBy(x, y); }

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_to_top(self : Self) =
  #| (self) => { self.scrollTo(0, 0); }

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_to_bottom(self : Self) =
  #| (self) => { self.scrollTo(0, document.body.scrollHeight); }

///|
#cfg(target="js")
pub extern "js" fn Window::history_go_back(self : Self) =
  #| (self) => { self.history.back(); }

///|
#cfg(target="js")
pub extern "js" fn Window::history_go_forward(self : Self) =
  #| (self) => { self.history.forward(); }

///|
#cfg(target="js")
pub extern "js" fn Window::load_url(self : Self, url : String) =
  #| (self,url) => { self.location.href = url; }

///|
#cfg(target="js")
pub extern "js" fn Window::reload_url(self : Self) =
  #| (self) => { self.location.reload(); }

///|
#cfg(target="js")
pub extern "js" fn Window::push_url(self : Self, url : String) =
  #| (self,url) => { self.history.pushState(null, '', url); }

///|
#cfg(target="js")
pub extern "js" fn Window::current_url(self : Self) -> String =
  #| (self) => { return self.location.href; }

///|
#cfg(target="js")
pub extern "js" fn Window::replace_url(self : Self, url : String) =
  #| (self,url) => { self.history.replaceState(null, '', url); }

///|
#cfg(target="js")
pub extern "js" fn Window::inner_width(self : Self) -> Int = "(self) => self.innerWidth"

///|
#cfg(target="js")
pub extern "js" fn Window::inner_height(self : Self) -> Int = "(self) => self.innerHeight"

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_x(self : Self) -> Int = "(self) => self.scrollX"

///|
#cfg(target="js")
pub extern "js" fn Window::scroll_y(self : Self) -> Int = "(self) => self.scrollY"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/Window/setInterval
#cfg(target="js")
pub extern "js" fn Window::set_interval(
  self : Self,
  f : () -> Unit,
  ms : Int,
) -> Int = "(self,f,ms) => self.setInterval(f, ms)"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/Window/clearInterval
#cfg(target="js")
pub extern "js" fn Window::clear_interval(self : Self, interval_id : Int) = "(self,id) => self.clearInterval(id)"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame
#cfg(target="js")
pub extern "js" fn Window::request_animation_frame(
  self : Self,
  f : (DOMHighResTimeStamp) -> Unit,
) -> Double = "(self,f) => self.requestAnimationFrame(f)"

///|
/// https://developer.mozilla.org/en-US/docs/Web/API/Window/cancelAnimationFrame
#cfg(target="js")
pub extern "js" fn Window::cancel_animation_frame(
  self : Self,
  request_id : Double,
) = "(self,id) => self.cancelAnimationFrame(id)"

///|
#cfg(target="js")
pub extern "js" fn window() -> Window = "() => window"

///|
#cfg(target="js")
pub extern "js" fn Window::to_event_target(self : Self) -> EventTarget = "(x) => x"

///|
#cfg(target="js")
pub extern "js" fn Window::alert(self : Self, msg : String) = "(self,msg) => self.alert(msg)"

///|
#cfg(target="js")
pub extern "js" fn Window::confirm(self : Self, msg : String) -> Bool = "(self,msg) => self.confirm(msg)"

///|
#cfg(target="js")
pub extern "js" fn Window::navigator(self : Self) -> Navigator =
  #| (self) => self.navigator
