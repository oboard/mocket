///|
using @cmd {type Cmd}

///|
/// Create a command to scroll the window to a specific position.
#cfg(target="js")
pub fn scroll_to_pos(x : Int, y : Int) -> Cmd {
  @cmd.custom_cmd(kind=AfterRender, _ => @dom.window().scroll_to(x, y))
}

///|
/// Create a command to scroll the window by a specific amount.
#cfg(target="js")
pub fn scroll_by_pos(x : Int, y : Int) -> Cmd {
  @cmd.custom_cmd(kind=AfterRender, _ => @dom.window().scroll_by(x, y))
}

///|
/// Create a command to scroll the window to a specific element.
/// The element is specified by its id.
#cfg(target="js")
pub fn scroll_to(element : String) -> Cmd {
  @cmd.custom_cmd(kind=AfterRender, _ => {
    match @dom.document().get_element_by_id(element).to_option() {
      Some(e) => e.scroll_into_view()
      None => ()
    }
  })
}

///|
/// Create a command to scroll the window to the top.
#cfg(target="js")
pub fn scroll_to_top() -> Cmd {
  @cmd.custom_cmd(kind=AfterRender, _ => @dom.window().scroll_to_top())
}

///|
/// Create a command to scroll the window to the bottom.
#cfg(target="js")
pub fn scroll_to_bottom() -> Cmd {
  @cmd.custom_cmd(kind=AfterRender, _ => @dom.window().scroll_to_bottom())
}
