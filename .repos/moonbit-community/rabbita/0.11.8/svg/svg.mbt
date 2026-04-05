///|
#alias(T)
pub(all) struct Svg(@runtime.VNode)

///|
pub fn Svg::to_virtual_dom(self : Svg) -> @runtime.VNode {
  self.0
}

///|
pub fn Svg::to_html(self : Svg) -> @html.Html {
  @html.Html::from_vnode(self.0)
}

///|
pub fn Svg::from_vnode(vdom : @runtime.VNode) -> Svg {
  Svg(vdom)
}

///|
pub fn node(
  tag : String,
  attrs : Attrs,
  children : Array[Svg],
  ns? : String = @dom.namespace_svg,
) -> Svg {
  let vnode = @runtime.VNode::elem(
    tag,
    attrs.to_props(),
    @runtime.Children::Array(children.map(x => x.0)),
    namespace_uri=ns,
  )
  Svg(vnode)
}

///|
fn resolve_attrs(attrs : Attrs?) -> Attrs {
  match attrs {
    Some(a) => a
    None => Attrs::build()
  }
}

///|
pub fn text(value : String) -> Svg {
  Svg(@runtime.VNode::text(value))
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/svg)
pub fn svg(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  width? : Int,
  height? : Int,
  // optional
  view_box? : String,
  xmlns? : String,
  attrs? : Attrs,
  children : Array[Svg],
) -> @html.Html {
  let attrs = resolve_attrs(attrs)
  push_width(width, attrs)
  push_height(height, attrs)
  push_view_box(view_box, attrs)
  push_xmlns(xmlns, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("svg", attrs, children).to_html()
}

///|
fn push_attr_string(name : String, value : String?, attrs : Attrs) -> Unit {
  if value is Some(v) {
    ignore(attrs.attribute(name, v))
  }
}

///|
fn push_attr_int(name : String, value : Int?, attrs : Attrs) -> Unit {
  if value is Some(v) {
    ignore(attrs.attribute(name, v.to_string()))
  }
}

///|
fn push_id(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("id", value, attrs)
}

///|
fn push_class(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("class", value, attrs)
}

///|
fn push_style(value : Array[String]?, attrs : Attrs) -> Unit {
  if value is Some(v) {
    ignore(attrs.style_attr(v.join(";")))
  }
}

///|
fn push_width(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("width", value, attrs)
}

///|
fn push_height(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("height", value, attrs)
}

///|
fn push_view_box(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("viewBox", value, attrs)
}

///|
fn push_xmlns(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("xmlns", value, attrs)
}

///|
fn push_x(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("x", value, attrs)
}

///|
fn push_y(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("y", value, attrs)
}

///|
fn push_rx(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("rx", value, attrs)
}

///|
fn push_ry(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("ry", value, attrs)
}

///|
fn push_fill(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("fill", value, attrs)
}

///|
fn push_stroke(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("stroke", value, attrs)
}

///|
fn push_stroke_width(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("stroke-width", value, attrs)
}

///|
fn push_cx(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("cx", value, attrs)
}

///|
fn push_cy(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("cy", value, attrs)
}

///|
fn push_r(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("r", value, attrs)
}

///|
fn push_dx(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("dx", value, attrs)
}

///|
fn push_dy(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("dy", value, attrs)
}

///|
fn push_rotate(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("rotate", value, attrs)
}

///|
fn push_length_adjust(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("lengthAdjust", value, attrs)
}

///|
fn push_text_length(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("textLength", value, attrs)
}

///|
fn push_d(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("d", value, attrs)
}

///|
fn push_href(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("href", value, attrs)
}

///|
fn push_fill_opacity(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("fill-opacity", value, attrs)
}

///|
fn push_zoom_and_pan(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("zoomAndPan", value, attrs)
}

///|
fn push_preserve_aspect_ratio(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("preserveAspectRatio", value, attrs)
}

///|
fn push_x1(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("x1", value, attrs)
}

///|
fn push_y1(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("y1", value, attrs)
}

///|
fn push_x2(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("x2", value, attrs)
}

///|
fn push_y2(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("y2", value, attrs)
}

///|
fn push_stroke_linecap(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("stroke-linecap", value, attrs)
}

///|
fn push_points(points : Array[(Int, Int)], attrs : Attrs) -> Unit {
  if points.length() > 0 {
    let points_str = points.map(pt => "\{pt.0},\{pt.1}").join(" ")
    ignore(attrs.attribute("points", points_str))
  }
}

///|
fn push_path_length(value : Int?, attrs : Attrs) -> Unit {
  push_attr_int("pathLength", value, attrs)
}

///|
fn push_text_content(value : String, attrs : Attrs) -> Unit {
  ignore(attrs.property("textContent", @variant.String(value)))
}

///|
fn push_transform(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("transform", value, attrs)
}

///|
fn push_opacity(value : String?, attrs : Attrs) -> Unit {
  push_attr_string("opacity", value, attrs)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/rect)
pub fn rect(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
  // optional
  rx? : Int,
  ry? : Int,
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_x(Some(x), attrs)
  push_y(Some(y), attrs)
  push_width(Some(width), attrs)
  push_height(Some(height), attrs)
  push_rx(rx, attrs)
  push_ry(ry, attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("rect", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/ellipse)
pub fn ellipse(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  cx~ : Int,
  cy~ : Int,
  rx~ : Int,
  ry~ : Int,
  // optional
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_cx(Some(cx), attrs)
  push_cy(Some(cy), attrs)
  push_rx(Some(rx), attrs)
  push_ry(Some(ry), attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("ellipse", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/text)
pub fn svg_text(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  x~ : Int,
  y~ : Int,
  text~ : String,
  // optional
  dx? : Int,
  dy? : Int,
  rotate? : String,
  length_adjust? : String,
  text_length? : Int,
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_x(Some(x), attrs)
  push_y(Some(y), attrs)
  push_text_content(text, attrs)
  push_dx(dx, attrs)
  push_dy(dy, attrs)
  push_rotate(rotate, attrs)
  push_length_adjust(length_adjust, attrs)
  push_text_length(text_length, attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("text", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/path)
pub fn path(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  d~ : String,
  // optional
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_d(Some(d), attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("path", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/g)
pub fn g(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // optional
  fill? : String,
  stroke? : String,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("g", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/defs)
pub fn defs(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("defs", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use)
pub fn svg_use(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  href~ : String,
  x~ : Int,
  y~ : Int,
  // optional
  width? : Int,
  height? : Int,
  stroke? : String,
  stroke_width? : Int,
  fill? : String,
  fill_opacity? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_href(Some(href), attrs)
  push_x(Some(x), attrs)
  push_y(Some(y), attrs)
  push_width(width, attrs)
  push_height(height, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_fill(fill, attrs)
  push_fill_opacity(fill_opacity, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("use", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/view)
pub fn view(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // optional
  view_box? : String,
  zoom_and_pan? : String,
  preserve_aspect_ratio? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_view_box(view_box, attrs)
  push_zoom_and_pan(zoom_and_pan, attrs)
  push_preserve_aspect_ratio(preserve_aspect_ratio, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("view", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/image)
pub fn image(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  href~ : String,
  x~ : Int,
  y~ : Int,
  // optional
  width? : Int,
  height? : Int,
  preserve_aspect_ratio? : String,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_href(Some(href), attrs)
  push_x(Some(x), attrs)
  push_y(Some(y), attrs)
  push_width(width, attrs)
  push_height(height, attrs)
  push_preserve_aspect_ratio(preserve_aspect_ratio, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("image", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/circle)
pub fn circle(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  cx~ : Int,
  cy~ : Int,
  r~ : Int,
  // optional
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  fill_opacity? : Int,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_cx(Some(cx), attrs)
  push_cy(Some(cy), attrs)
  push_r(Some(r), attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_fill_opacity(fill_opacity, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("circle", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/line)
pub fn line(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  x1~ : Int,
  y1~ : Int,
  x2~ : Int,
  y2~ : Int,
  // optional
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  stroke_linecap? : String,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_x1(Some(x1), attrs)
  push_y1(Some(y1), attrs)
  push_x2(Some(x2), attrs)
  push_y2(Some(y2), attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_stroke_linecap(stroke_linecap, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("line", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/polyline)
pub fn polyline(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  points~ : Array[(Int, Int)],
  // optional
  path_length? : Int,
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  stroke_linecap? : String,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_points(points, attrs)
  push_path_length(path_length, attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_stroke_linecap(stroke_linecap, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("polyline", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/polygon)
pub fn polygon(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  // required
  points~ : Array[(Int, Int)],
  // optional
  fill? : String,
  stroke? : String,
  stroke_width? : Int,
  stroke_linecap? : String,
  transform? : String,
  opacity? : String,
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_points(points, attrs)
  push_fill(fill, attrs)
  push_stroke(stroke, attrs)
  push_stroke_width(stroke_width, attrs)
  push_stroke_linecap(stroke_linecap, attrs)
  push_transform(transform, attrs)
  push_opacity(opacity, attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("polygon", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/clipPath)
pub fn clip_path(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("clipPath", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/filter)
pub fn filter(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("filter", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/linearGradient)
pub fn linear_gradient(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("linearGradient", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/radialGradient)
pub fn radial_gradient(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("radialGradient", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/marker)
pub fn marker(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("marker", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/pattern)
pub fn pattern(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("pattern", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/mask)
pub fn mask(
  // common attributes
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("mask", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/a)
pub fn a(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("a", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/animate)
pub fn animate(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("animate", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/animateMotion)
pub fn animate_motion(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("animateMotion", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/animateTransform)
pub fn animate_transform(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("animateTransform", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/desc)
pub fn desc(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("desc", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feBlend)
pub fn fe_blend(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feBlend", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feColorMatrix)
pub fn fe_color_matrix(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feColorMatrix", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feComponentTransfer)
pub fn fe_component_transfer(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feComponentTransfer", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feComposite)
pub fn fe_composite(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feComposite", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feConvolveMatrix)
pub fn fe_convolve_matrix(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feConvolveMatrix", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDiffuseLighting)
pub fn fe_diffuse_lighting(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feDiffuseLighting", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDisplacementMap)
pub fn fe_displacement_map(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feDisplacementMap", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDistantLight)
pub fn fe_distant_light(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feDistantLight", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDropShadow)
pub fn fe_drop_shadow(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feDropShadow", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feFlood)
pub fn fe_flood(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feFlood", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feFuncA)
pub fn fe_func_a(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feFuncA", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feFuncB)
pub fn fe_func_b(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feFuncB", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feFuncG)
pub fn fe_func_g(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feFuncG", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feFuncR)
pub fn fe_func_r(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feFuncR", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feGaussianBlur)
pub fn fe_gaussian_blur(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feGaussianBlur", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feImage)
pub fn fe_image(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feImage", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feMerge)
pub fn fe_merge(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feMerge", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feMergeNode)
pub fn fe_merge_node(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feMergeNode", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feMorphology)
pub fn fe_morphology(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feMorphology", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feOffset)
pub fn fe_offset(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feOffset", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/fePointLight)
pub fn fe_point_light(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("fePointLight", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feSpecularLighting)
pub fn fe_specular_lighting(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feSpecularLighting", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feSpotLight)
pub fn fe_spot_light(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feSpotLight", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feTile)
pub fn fe_tile(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feTile", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feTurbulence)
pub fn fe_turbulence(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("feTurbulence", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/foreignObject)
pub fn foreign_object(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("foreignObject", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/metadata)
pub fn metadata(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("metadata", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/mpath)
pub fn mpath(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("mpath", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/script)
pub fn script(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("script", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/set)
pub fn set(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("set", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/stop)
pub fn stop(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("stop", attrs, [])
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/style)
pub fn svg_style(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("style", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/switch)
pub fn switch(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("switch", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/symbol)
pub fn symbol(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("symbol", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/textPath)
pub fn text_path(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("textPath", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/title)
pub fn title(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("title", attrs, children)
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/tspan)
pub fn tspan(
  id? : String,
  class? : String,
  style? : Array[String],
  attrs? : Attrs,
  children : Array[Svg],
) -> Svg {
  let attrs = resolve_attrs(attrs)
  push_id(id, attrs)
  push_class(class, attrs)
  push_style(style, attrs)
  node("tspan", attrs, children)
}
