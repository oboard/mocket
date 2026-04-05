///|
#cfg(target="js")
#external
type MouseEvent

///|
#cfg(target="js")
pub trait IsMouseEvent: IsUIEvent {
  as_mouse_event(Self) -> MouseEvent = _
  get_alt_key(Self) -> Bool = _
  get_button(Self) -> Int = _
  get_buttons(Self) -> Int = _
  get_client_x(Self) -> Int = _
  get_client_y(Self) -> Int = _
  get_ctrl_key(Self) -> Bool = _
  get_meta_key(Self) -> Bool = _
  get_movement_x(Self) -> Int = _
  get_movement_y(Self) -> Int = _
  get_offset_x(Self) -> Int = _
  get_offset_y(Self) -> Int = _
  get_page_x(Self) -> Int = _
  get_page_y(Self) -> Int = _
  get_related_target(Self) -> EventTarget = _
  get_screen_x(Self) -> Int = _
  get_screen_y(Self) -> Int = _
  get_shift_key(Self) -> Bool = _
  get_x(Self) -> Int = _
  get_y(Self) -> Int = _
  get_modifier_state(Self) -> Int = _
}

///|
#cfg(target="js")
pub impl IsEvent for MouseEvent

///|
#cfg(target="js")
pub impl IsUIEvent for MouseEvent

///|
#cfg(target="js")
pub impl IsMouseEvent for MouseEvent

///|
#cfg(target="js")
pub impl @js.Cast for MouseEvent with into(value) {
  value |> ffi_to_mouse_event |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for MouseEvent with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
impl IsMouseEvent with as_mouse_event(s) {
  s |> js_identity
}

///|
#cfg(target="js")
impl IsMouseEvent with get_alt_key(s) {
  s |> js_identity |> ffi_mouse_event_alt_key
}

///|
#cfg(target="js")
impl IsMouseEvent with get_button(s) {
  s |> js_identity |> ffi_mouse_event_button
}

///|
#cfg(target="js")
impl IsMouseEvent with get_buttons(s) {
  s |> js_identity |> ffi_mouse_event_buttons
}

///|
#cfg(target="js")
impl IsMouseEvent with get_client_x(s) {
  s |> js_identity |> ffi_mouse_event_client_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_client_y(s) {
  s |> js_identity |> ffi_mouse_event_client_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_ctrl_key(s) {
  s |> js_identity |> ffi_mouse_event_ctrl_key
}

///|
#cfg(target="js")
impl IsMouseEvent with get_meta_key(s) {
  s |> js_identity |> ffi_mouse_event_meta_key
}

///|
#cfg(target="js")
impl IsMouseEvent with get_movement_x(s) {
  s |> js_identity |> ffi_mouse_event_movement_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_movement_y(s) {
  s |> js_identity |> ffi_mouse_event_movement_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_offset_x(s) {
  s |> js_identity |> ffi_mouse_event_offset_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_offset_y(s) {
  s |> js_identity |> ffi_mouse_event_offset_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_page_x(s) {
  s |> js_identity |> ffi_mouse_event_page_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_page_y(s) {
  s |> js_identity |> ffi_mouse_event_page_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_related_target(s) {
  s |> js_identity |> ffi_mouse_event_related_target
}

///|
#cfg(target="js")
impl IsMouseEvent with get_screen_x(s) {
  s |> js_identity |> ffi_mouse_event_screen_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_screen_y(s) {
  s |> js_identity |> ffi_mouse_event_screen_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_shift_key(s) {
  s |> js_identity |> ffi_mouse_event_shift_key
}

///|
#cfg(target="js")
impl IsMouseEvent with get_x(s) {
  s |> js_identity |> ffi_mouse_event_x
}

///|
#cfg(target="js")
impl IsMouseEvent with get_y(s) {
  s |> js_identity |> ffi_mouse_event_y
}

///|
#cfg(target="js")
impl IsMouseEvent with get_modifier_state(s) {
  s |> js_identity |> ffi_mouse_event_modifier_state
}

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_screen_x(e : @js.Value) -> Int = "(e) => e.screenX"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_screen_y(e : @js.Value) -> Int = "(e) => e.screenY"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_client_x(e : @js.Value) -> Int = "(e) => e.clientX"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_client_y(e : @js.Value) -> Int = "(e) => e.clientY"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_offset_x(e : @js.Value) -> Int = "(e) => e.offsetX"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_offset_y(e : @js.Value) -> Int = "(e) => e.offsetY"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_ctrl_key(e : @js.Value) -> Bool = "(e) => e.ctrlKey"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_shift_key(e : @js.Value) -> Bool = "(e) => e.shiftKey"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_alt_key(e : @js.Value) -> Bool = "(e) => e.altKey"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_meta_key(e : @js.Value) -> Bool = "(e) => e.metaKey"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_button(e : @js.Value) -> Int = "(e) => e.button"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_buttons(e : @js.Value) -> Int = "(e) => e.buttons"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_movement_x(e : @js.Value) -> Int = "(e) => e.movementX"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_movement_y(e : @js.Value) -> Int = "(e) => e.movementY"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_page_x(e : @js.Value) -> Int = "(e) => e.pageX"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_page_y(e : @js.Value) -> Int = "(e) => e.pageY"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_related_target(e : @js.Value) -> EventTarget = "(e) => e.relatedTarget"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_x(e : @js.Value) -> Int = "(e) => e.x"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_y(e : @js.Value) -> Int = "(e) => e.y"

///|
#cfg(target="js")
extern "js" fn ffi_mouse_event_modifier_state(e : @js.Value) -> Int = "(e) => e.getModifierState()"
