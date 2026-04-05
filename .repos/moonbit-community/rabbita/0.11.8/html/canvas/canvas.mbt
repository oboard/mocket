///|
/// Get the 2D rendering context of a canvas by element id.
#cfg(target="js")
pub fn get_context2d(id : String) -> @dom.CanvasRenderingContext2D? {
  match @dom.document().get_element_by_id(id).to_option() {
    Some(element) =>
      match element.to_html_canvas_element() {
        Some(canvas) => canvas.get_context("2d").to0()
        None => None
      }
    None => None
  }
}
