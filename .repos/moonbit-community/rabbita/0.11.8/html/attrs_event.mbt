///|
#cfg(target="js")
type MouseEvent = @dom.MouseEvent

///|
#cfg(target="js")
type KeyboardEvent = @dom.KeyboardEvent

///|
#cfg(target="js")
type FocusEvent = @dom.FocusEvent

///|
#cfg(target="js")
type DragEvent = @dom.DragEvent

///|
#cfg(target="js")
type ClipboardEvent = @dom.ClipboardEvent

///|
#cfg(target="js")
type CompositionEvent = @dom.CompositionEvent

///|
#cfg(target="js")
type WheelEvent = @dom.WheelEvent

///|
#cfg(target="js")
type UIEvent = @dom.UIEvent

///|
#cfg(target="js")
type InputEvent = @dom.InputEvent

///|
#cfg(target="js")
type DomEvent = @dom.Event

///|
#cfg(not(target="js"))
type MouseEvent = Unit

///|
#cfg(not(target="js"))
type KeyboardEvent = Unit

///|
#cfg(not(target="js"))
type FocusEvent = Unit

///|
#cfg(not(target="js"))
type DragEvent = Unit

///|
#cfg(not(target="js"))
type ClipboardEvent = Unit

///|
#cfg(not(target="js"))
type CompositionEvent = Unit

///|
#cfg(not(target="js"))
type WheelEvent = Unit

///|
#cfg(not(target="js"))
type UIEvent = Unit

///|
#cfg(not(target="js"))
type InputEvent = Unit

///|
#cfg(not(target="js"))
type DomEvent = Unit

///|
#cfg(target="js")
fn Attrs::on_mouse_event(
  self : Attrs,
  event : String,
  msg : (MouseEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_mouse_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_mouse_event(
  self : Attrs,
  event : String,
  msg : (MouseEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_keyboard_event(
  self : Attrs,
  event : String,
  msg : (KeyboardEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_keyboard_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_keyboard_event(
  self : Attrs,
  event : String,
  msg : (KeyboardEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_focus_event(
  self : Attrs,
  event : String,
  msg : (FocusEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_focus_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_focus_event(
  self : Attrs,
  event : String,
  msg : (FocusEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_drag_event(
  self : Attrs,
  event : String,
  msg : (DragEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_drag_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_drag_event(
  self : Attrs,
  event : String,
  msg : (DragEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_clipboard_event(
  self : Attrs,
  event : String,
  msg : (ClipboardEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_clipboard_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_clipboard_event(
  self : Attrs,
  event : String,
  msg : (ClipboardEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_composition_event(
  self : Attrs,
  event : String,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_composition_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_composition_event(
  self : Attrs,
  event : String,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
#cfg(target="js")
fn Attrs::on_wheel_event(
  self : Attrs,
  event : String,
  msg : (WheelEvent) -> Cmd,
) -> Attrs {
  self.handler(event, (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_wheel_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
fn Attrs::on_wheel_event(
  self : Attrs,
  event : String,
  msg : (WheelEvent) -> Cmd,
) -> Attrs {
  ignore((event, msg))
  self
}

///|
pub fn Attrs::on_click(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("click", msg)
}

///|
pub fn Attrs::on_dblclick(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("dblclick", msg)
}

///|
pub fn Attrs::on_dbclick(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_dblclick(msg)
}

///|
pub fn Attrs::on_mousedown(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mousedown", msg)
}

///|
pub fn Attrs::on_mouseup(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mouseup", msg)
}

///|
pub fn Attrs::on_mousemove(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mousemove", msg)
}

///|
pub fn Attrs::on_mouseenter(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mouseenter", msg)
}

///|
pub fn Attrs::on_mouseover(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mouseover", msg)
}

///|
pub fn Attrs::on_mouseleave(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mouseleave", msg)
}

///|
pub fn Attrs::on_mouseout(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("mouseout", msg)
}

///|
pub fn Attrs::on_contextmenu(self : Attrs, msg : (MouseEvent) -> Cmd) -> Attrs {
  self.on_mouse_event("contextmenu", msg)
}

///|
#cfg(target="js")
pub fn Attrs::on_scroll(self : Attrs, msg : (UIEvent) -> Cmd) -> Attrs {
  self.handler("scroll", (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_ui_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_scroll(self : Attrs, msg : (UIEvent) -> Cmd) -> Attrs {
  ignore(msg)
  self
}

///|
pub fn Attrs::on_wheel(self : Attrs, msg : (WheelEvent) -> Cmd) -> Attrs {
  self.on_wheel_event("wheel", msg)
}

///|
#cfg(target="js")
pub fn Attrs::on_input(self : Attrs, msg : (InputEvent) -> Cmd) -> Attrs {
  self.handler("input", (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_input_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_input(self : Attrs, msg : (InputEvent) -> Cmd) -> Attrs {
  ignore(msg)
  self
}

///|
#cfg(target="js")
pub fn Attrs::on_change(self : Attrs, msg : (InputEvent) -> Cmd) -> Attrs {
  self.handler("change", (event, scheduler) => {
    scheduler.add_cmds(msg(event.to_input_event().unwrap()).to_array())
  })
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_change(self : Attrs, msg : (InputEvent) -> Cmd) -> Attrs {
  ignore(msg)
  self
}

///|
pub fn Attrs::on_focus(self : Attrs, msg : (FocusEvent) -> Cmd) -> Attrs {
  self.on_focus_event("focus", msg)
}

///|
pub fn Attrs::on_blur(self : Attrs, msg : (FocusEvent) -> Cmd) -> Attrs {
  self.on_focus_event("blur", msg)
}

///|
pub fn Attrs::on_keydown(self : Attrs, msg : (KeyboardEvent) -> Cmd) -> Attrs {
  self.on_keyboard_event("keydown", msg)
}

///|
pub fn Attrs::on_keyup(self : Attrs, msg : (KeyboardEvent) -> Cmd) -> Attrs {
  self.on_keyboard_event("keyup", msg)
}

///|
pub fn Attrs::on_submit(self : Attrs, msg : (DomEvent) -> Cmd) -> Attrs {
  self.handler("submit", (event, scheduler) => {
    scheduler.add_cmds(msg(event).to_array())
  })
}

///|
pub fn Attrs::on_reset(self : Attrs, msg : (DomEvent) -> Cmd) -> Attrs {
  self.handler("reset", (event, scheduler) => {
    scheduler.add_cmds(msg(event).to_array())
  })
}

///|
pub fn Attrs::on_dragstart(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("dragstart", msg)
}

///|
pub fn Attrs::on_dragover(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("dragover", msg)
}

///|
pub fn Attrs::on_dragenter(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("dragenter", msg)
}

///|
pub fn Attrs::on_dragleave(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("dragleave", msg)
}

///|
pub fn Attrs::on_dragend(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("dragend", msg)
}

///|
pub fn Attrs::on_drop(self : Attrs, msg : (DragEvent) -> Cmd) -> Attrs {
  self.on_drag_event("drop", msg)
}

///|
pub fn Attrs::on_copy(self : Attrs, msg : (ClipboardEvent) -> Cmd) -> Attrs {
  self.on_clipboard_event("copy", msg)
}

///|
pub fn Attrs::on_cut(self : Attrs, msg : (ClipboardEvent) -> Cmd) -> Attrs {
  self.on_clipboard_event("cut", msg)
}

///|
pub fn Attrs::on_paste(self : Attrs, msg : (ClipboardEvent) -> Cmd) -> Attrs {
  self.on_clipboard_event("paste", msg)
}

///|
#cfg(target="js")
pub fn Attrs::on_compositionstart(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  self.on_composition_event("compositionstart", msg)
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_compositionstart(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  ignore(msg)
  self
}

///|
#cfg(target="js")
pub fn Attrs::on_compositionupdate(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  self.on_composition_event("compositionupdate", msg)
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_compositionupdate(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  ignore(msg)
  self
}

///|
#cfg(target="js")
pub fn Attrs::on_compositionend(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  self.on_composition_event("compositionend", msg)
}

///|
#cfg(not(target="js"))
pub fn Attrs::on_compositionend(
  self : Attrs,
  msg : (CompositionEvent) -> Cmd,
) -> Attrs {
  ignore(msg)
  self
}
