///|
using @runtime {type Props}

///|
using @variant {type Variant}

///|
#cfg(not(target="js"))
type Event = Unit

///|
struct Attrs(Props)

///|
pub fn Attrs::build() -> Attrs {
  Attrs(Props::new({}, {}, {}, {}))
}

///|
fn Attrs::to_props(self : Attrs) -> Props {
  self.0
}

///|
/// Set a raw attribute.
fn Attrs::attribute(self : Attrs, key : String, value : String) -> Attrs {
  self.0.attrs[key] = value
  self
}

///|
/// Set a property.
fn Attrs::property(self : Attrs, key : String, value : Variant) -> Attrs {
  self.0.props[key] = value
  self
}

///|
/// Sets raw HTML and bypasses normal escaping.
/// 
/// # Vulnerability Warning
///
/// This is **XSS‑prone** and should
/// only be used with trusted or sanitized input. It affects both HTML and SVG
/// content since the browser will parse the string into DOM nodes.
#internal(xss_vulnerable, "This function may cause xss attack.")
pub fn Attrs::inner_html(self : Attrs, html : String) -> Attrs {
  self.0.props["innerHTML"] = @variant.String(html)
  self.0
}

///|
/// Set a style declaration.
pub fn Attrs::style(self : Attrs, key : String, value : String) -> Attrs {
  self.0.styles[key] = value
  self
}

// ///|
// /// Set an event handler.
// fn Attrs::handler(
//   self : Attrs,
//   key : String,
//   value : (Event, &@interface.Scheduler) -> Unit,
// ) -> Attrs {
//   self.0.handlers[key] = value
//   self
// }

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/style)
pub fn Attrs::style_attr(self : Attrs, value : String) -> Attrs {
  self.0.attrs["style"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/data-*)
pub fn Attrs::data_set(self : Attrs, name : String, value : String) -> Attrs {
  self.0.attrs["data-" + name] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/accumulate)
pub fn Attrs::accumulate(self : Attrs, value : String) -> Attrs {
  self.0.attrs["accumulate"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/additive)
pub fn Attrs::additive(self : Attrs, value : String) -> Attrs {
  self.0.attrs["additive"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/alignment-baseline)
pub fn Attrs::alignment_baseline(self : Attrs, value : String) -> Attrs {
  self.0.attrs["alignment-baseline"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/amplitude)
pub fn Attrs::amplitude(self : Attrs, value : String) -> Attrs {
  self.0.attrs["amplitude"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/attributeName)
pub fn Attrs::attribute_name(self : Attrs, value : String) -> Attrs {
  self.0.attrs["attributeName"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/attributeType)
pub fn Attrs::attribute_type(self : Attrs, value : String) -> Attrs {
  self.0.attrs["attributeType"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/autofocus)
pub fn Attrs::autofocus(self : Attrs, value : String) -> Attrs {
  self.0.attrs["autofocus"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/azimuth)
pub fn Attrs::azimuth(self : Attrs, value : String) -> Attrs {
  self.0.attrs["azimuth"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/baseFrequency)
pub fn Attrs::base_frequency(self : Attrs, value : String) -> Attrs {
  self.0.attrs["baseFrequency"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/baseline-shift)
pub fn Attrs::baseline_shift(self : Attrs, value : String) -> Attrs {
  self.0.attrs["baseline-shift"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/baseProfile)
pub fn Attrs::base_profile(self : Attrs, value : String) -> Attrs {
  self.0.attrs["baseProfile"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/begin)
pub fn Attrs::begin(self : Attrs, value : String) -> Attrs {
  self.0.attrs["begin"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/bias)
pub fn Attrs::bias(self : Attrs, value : String) -> Attrs {
  self.0.attrs["bias"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/by)
pub fn Attrs::by(self : Attrs, value : String) -> Attrs {
  self.0.attrs["by"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/calcMode)
pub fn Attrs::calc_mode(self : Attrs, value : String) -> Attrs {
  self.0.attrs["calcMode"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/class)
pub fn Attrs::class(self : Attrs, value : String) -> Attrs {
  self.0.attrs["class"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/clip)
pub fn Attrs::clip(self : Attrs, value : String) -> Attrs {
  self.0.attrs["clip"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/clipPathUnits)
pub fn Attrs::clip_path_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["clipPathUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/clip-path)
pub fn Attrs::clip_path(self : Attrs, value : String) -> Attrs {
  self.0.attrs["clip-path"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/clip-rule)
pub fn Attrs::clip_rule(self : Attrs, value : String) -> Attrs {
  self.0.attrs["clip-rule"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/color)
pub fn Attrs::color(self : Attrs, value : String) -> Attrs {
  self.0.attrs["color"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/color-interpolation)
pub fn Attrs::color_interpolation(self : Attrs, value : String) -> Attrs {
  self.0.attrs["color-interpolation"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/color-interpolation-filters)
pub fn Attrs::color_interpolation_filters(
  self : Attrs,
  value : String,
) -> Attrs {
  self.0.attrs["color-interpolation-filters"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/crossorigin)
pub fn Attrs::crossorigin(self : Attrs, value : String) -> Attrs {
  self.0.attrs["crossorigin"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/cursor)
pub fn Attrs::cursor(self : Attrs, value : String) -> Attrs {
  self.0.attrs["cursor"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/cx)
pub fn Attrs::cx(self : Attrs, value : String) -> Attrs {
  self.0.attrs["cx"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/cy)
pub fn Attrs::cy(self : Attrs, value : String) -> Attrs {
  self.0.attrs["cy"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/d)
pub fn Attrs::d(self : Attrs, value : String) -> Attrs {
  self.0.attrs["d"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/decoding)
pub fn Attrs::decoding(self : Attrs, value : String) -> Attrs {
  self.0.attrs["decoding"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/diffuseConstant)
pub fn Attrs::diffuse_constant(self : Attrs, value : String) -> Attrs {
  self.0.attrs["diffuseConstant"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/direction)
pub fn Attrs::direction(self : Attrs, value : String) -> Attrs {
  self.0.attrs["direction"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/display)
pub fn Attrs::display(self : Attrs, value : String) -> Attrs {
  self.0.attrs["display"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/divisor)
pub fn Attrs::divisor(self : Attrs, value : String) -> Attrs {
  self.0.attrs["divisor"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/dominant-baseline)
pub fn Attrs::dominant_baseline(self : Attrs, value : String) -> Attrs {
  self.0.attrs["dominant-baseline"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/dur)
pub fn Attrs::dur(self : Attrs, value : String) -> Attrs {
  self.0.attrs["dur"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/dx)
pub fn Attrs::dx(self : Attrs, value : String) -> Attrs {
  self.0.attrs["dx"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/dy)
pub fn Attrs::dy(self : Attrs, value : String) -> Attrs {
  self.0.attrs["dy"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/edgeMode)
pub fn Attrs::edge_mode(self : Attrs, value : String) -> Attrs {
  self.0.attrs["edgeMode"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/elevation)
pub fn Attrs::elevation(self : Attrs, value : String) -> Attrs {
  self.0.attrs["elevation"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/end)
pub fn Attrs::end(self : Attrs, value : String) -> Attrs {
  self.0.attrs["end"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/exponent)
pub fn Attrs::exponent(self : Attrs, value : String) -> Attrs {
  self.0.attrs["exponent"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fetchpriority)
pub fn Attrs::fetchpriority(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fetchpriority"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fill)
pub fn Attrs::fill(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fill"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fill-opacity)
pub fn Attrs::fill_opacity(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fill-opacity"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fill-rule)
pub fn Attrs::fill_rule(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fill-rule"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/filter)
pub fn Attrs::filter(self : Attrs, value : String) -> Attrs {
  self.0.attrs["filter"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/filterUnits)
pub fn Attrs::filter_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["filterUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/flood-color)
pub fn Attrs::flood_color(self : Attrs, value : String) -> Attrs {
  self.0.attrs["flood-color"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/flood-opacity)
pub fn Attrs::flood_opacity(self : Attrs, value : String) -> Attrs {
  self.0.attrs["flood-opacity"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-family)
pub fn Attrs::font_family(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-family"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-size)
pub fn Attrs::font_size(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-size"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-size-adjust)
pub fn Attrs::font_size_adjust(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-size-adjust"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-stretch)
pub fn Attrs::font_stretch(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-stretch"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-style)
pub fn Attrs::font_style(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-style"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-variant)
pub fn Attrs::font_variant(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-variant"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/font-weight)
pub fn Attrs::font_weight(self : Attrs, value : String) -> Attrs {
  self.0.attrs["font-weight"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fr)
pub fn Attrs::fr(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fr"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/from)
pub fn Attrs::from(self : Attrs, value : String) -> Attrs {
  self.0.attrs["from"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fx)
pub fn Attrs::fx(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fx"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/fy)
pub fn Attrs::fy(self : Attrs, value : String) -> Attrs {
  self.0.attrs["fy"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/glyph-orientation-horizontal)
pub fn Attrs::glyph_orientation_horizontal(
  self : Attrs,
  value : String,
) -> Attrs {
  self.0.attrs["glyph-orientation-horizontal"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/glyph-orientation-vertical)
pub fn Attrs::glyph_orientation_vertical(self : Attrs, value : String) -> Attrs {
  self.0.attrs["glyph-orientation-vertical"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/gradientTransform)
pub fn Attrs::gradient_transform(self : Attrs, value : String) -> Attrs {
  self.0.attrs["gradientTransform"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/gradientUnits)
pub fn Attrs::gradient_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["gradientUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/height)
pub fn Attrs::height(self : Attrs, value : String) -> Attrs {
  self.0.attrs["height"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/href)
pub fn Attrs::href(self : Attrs, value : String) -> Attrs {
  self.0.attrs["href"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/hreflang)
pub fn Attrs::hreflang(self : Attrs, value : String) -> Attrs {
  self.0.attrs["hreflang"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/id)
pub fn Attrs::id(self : Attrs, value : String) -> Attrs {
  self.0.attrs["id"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/image-rendering)
pub fn Attrs::image_rendering(self : Attrs, value : String) -> Attrs {
  self.0.attrs["image-rendering"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/in)
pub fn Attrs::in_(self : Attrs, value : String) -> Attrs {
  self.0.attrs["in"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/in2)
pub fn Attrs::in2(self : Attrs, value : String) -> Attrs {
  self.0.attrs["in2"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/intercept)
pub fn Attrs::intercept(self : Attrs, value : String) -> Attrs {
  self.0.attrs["intercept"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/k1)
pub fn Attrs::k1(self : Attrs, value : String) -> Attrs {
  self.0.attrs["k1"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/k2)
pub fn Attrs::k2(self : Attrs, value : String) -> Attrs {
  self.0.attrs["k2"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/k3)
pub fn Attrs::k3(self : Attrs, value : String) -> Attrs {
  self.0.attrs["k3"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/k4)
pub fn Attrs::k4(self : Attrs, value : String) -> Attrs {
  self.0.attrs["k4"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/kernelMatrix)
pub fn Attrs::kernel_matrix(self : Attrs, value : String) -> Attrs {
  self.0.attrs["kernelMatrix"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/kernelUnitLength)
pub fn Attrs::kernel_unit_length(self : Attrs, value : String) -> Attrs {
  self.0.attrs["kernelUnitLength"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/keyPoints)
pub fn Attrs::key_points(self : Attrs, value : String) -> Attrs {
  self.0.attrs["keyPoints"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/keySplines)
pub fn Attrs::key_splines(self : Attrs, value : String) -> Attrs {
  self.0.attrs["keySplines"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/keyTimes)
pub fn Attrs::key_times(self : Attrs, value : String) -> Attrs {
  self.0.attrs["keyTimes"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/lang)
pub fn Attrs::lang(self : Attrs, value : String) -> Attrs {
  self.0.attrs["lang"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/lengthAdjust)
pub fn Attrs::length_adjust(self : Attrs, value : String) -> Attrs {
  self.0.attrs["lengthAdjust"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/letter-spacing)
pub fn Attrs::letter_spacing(self : Attrs, value : String) -> Attrs {
  self.0.attrs["letter-spacing"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/lighting-color)
pub fn Attrs::lighting_color(self : Attrs, value : String) -> Attrs {
  self.0.attrs["lighting-color"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/limitingConeAngle)
pub fn Attrs::limiting_cone_angle(self : Attrs, value : String) -> Attrs {
  self.0.attrs["limitingConeAngle"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/marker-end)
pub fn Attrs::marker_end(self : Attrs, value : String) -> Attrs {
  self.0.attrs["marker-end"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/marker-mid)
pub fn Attrs::marker_mid(self : Attrs, value : String) -> Attrs {
  self.0.attrs["marker-mid"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/marker-start)
pub fn Attrs::marker_start(self : Attrs, value : String) -> Attrs {
  self.0.attrs["marker-start"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/markerHeight)
pub fn Attrs::marker_height(self : Attrs, value : String) -> Attrs {
  self.0.attrs["markerHeight"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/markerUnits)
pub fn Attrs::marker_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["markerUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/markerWidth)
pub fn Attrs::marker_width(self : Attrs, value : String) -> Attrs {
  self.0.attrs["markerWidth"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/mask)
pub fn Attrs::mask(self : Attrs, value : String) -> Attrs {
  self.0.attrs["mask"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/maskContentUnits)
pub fn Attrs::mask_content_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["maskContentUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/maskUnits)
pub fn Attrs::mask_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["maskUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/max)
pub fn Attrs::max(self : Attrs, value : String) -> Attrs {
  self.0.attrs["max"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/media)
pub fn Attrs::media(self : Attrs, value : String) -> Attrs {
  self.0.attrs["media"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/method)
pub fn Attrs::method_(self : Attrs, value : String) -> Attrs {
  self.0.attrs["method"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/min)
pub fn Attrs::min(self : Attrs, value : String) -> Attrs {
  self.0.attrs["min"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/mode)
pub fn Attrs::mode(self : Attrs, value : String) -> Attrs {
  self.0.attrs["mode"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/numOctaves)
pub fn Attrs::num_octaves(self : Attrs, value : String) -> Attrs {
  self.0.attrs["numOctaves"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/offset)
pub fn Attrs::offset(self : Attrs, value : String) -> Attrs {
  self.0.attrs["offset"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/opacity)
pub fn Attrs::opacity(self : Attrs, value : String) -> Attrs {
  self.0.attrs["opacity"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/operator)
pub fn Attrs::operator(self : Attrs, value : String) -> Attrs {
  self.0.attrs["operator"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/order)
pub fn Attrs::order(self : Attrs, value : String) -> Attrs {
  self.0.attrs["order"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/orient)
pub fn Attrs::orient(self : Attrs, value : String) -> Attrs {
  self.0.attrs["orient"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/origin)
pub fn Attrs::origin(self : Attrs, value : String) -> Attrs {
  self.0.attrs["origin"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/overflow)
pub fn Attrs::overflow(self : Attrs, value : String) -> Attrs {
  self.0.attrs["overflow"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/paint-order)
pub fn Attrs::paint_order(self : Attrs, value : String) -> Attrs {
  self.0.attrs["paint-order"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/path)
pub fn Attrs::path(self : Attrs, value : String) -> Attrs {
  self.0.attrs["path"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/pathLength)
pub fn Attrs::path_length(self : Attrs, value : String) -> Attrs {
  self.0.attrs["pathLength"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/patternContentUnits)
pub fn Attrs::pattern_content_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["patternContentUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/patternTransform)
pub fn Attrs::pattern_transform(self : Attrs, value : String) -> Attrs {
  self.0.attrs["patternTransform"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/patternUnits)
pub fn Attrs::pattern_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["patternUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/ping)
pub fn Attrs::ping(self : Attrs, value : String) -> Attrs {
  self.0.attrs["ping"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/pointer-events)
pub fn Attrs::pointer_events(self : Attrs, value : String) -> Attrs {
  self.0.attrs["pointer-events"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/points)
pub fn Attrs::points(self : Attrs, value : String) -> Attrs {
  self.0.attrs["points"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/pointsAtX)
pub fn Attrs::points_at_x(self : Attrs, value : String) -> Attrs {
  self.0.attrs["pointsAtX"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/pointsAtY)
pub fn Attrs::points_at_y(self : Attrs, value : String) -> Attrs {
  self.0.attrs["pointsAtY"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/pointsAtZ)
pub fn Attrs::points_at_z(self : Attrs, value : String) -> Attrs {
  self.0.attrs["pointsAtZ"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/preserveAlpha)
pub fn Attrs::preserve_alpha(self : Attrs, value : String) -> Attrs {
  self.0.attrs["preserveAlpha"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/preserveAspectRatio)
pub fn Attrs::preserve_aspect_ratio(self : Attrs, value : String) -> Attrs {
  self.0.attrs["preserveAspectRatio"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/primitiveUnits)
pub fn Attrs::primitive_units(self : Attrs, value : String) -> Attrs {
  self.0.attrs["primitiveUnits"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/r)
pub fn Attrs::r(self : Attrs, value : String) -> Attrs {
  self.0.attrs["r"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/radius)
pub fn Attrs::radius(self : Attrs, value : String) -> Attrs {
  self.0.attrs["radius"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/referrerPolicy)
pub fn Attrs::referrer_policy(self : Attrs, value : String) -> Attrs {
  self.0.attrs["referrerPolicy"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/refX)
pub fn Attrs::ref_x(self : Attrs, value : String) -> Attrs {
  self.0.attrs["refX"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/refY)
pub fn Attrs::ref_y(self : Attrs, value : String) -> Attrs {
  self.0.attrs["refY"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/rel)
pub fn Attrs::rel(self : Attrs, value : String) -> Attrs {
  self.0.attrs["rel"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/repeatCount)
pub fn Attrs::repeat_count(self : Attrs, value : String) -> Attrs {
  self.0.attrs["repeatCount"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/repeatDur)
pub fn Attrs::repeat_dur(self : Attrs, value : String) -> Attrs {
  self.0.attrs["repeatDur"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/requiredExtensions)
pub fn Attrs::required_extensions(self : Attrs, value : String) -> Attrs {
  self.0.attrs["requiredExtensions"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/requiredFeatures)
pub fn Attrs::required_features(self : Attrs, value : String) -> Attrs {
  self.0.attrs["requiredFeatures"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/restart)
pub fn Attrs::restart(self : Attrs, value : String) -> Attrs {
  self.0.attrs["restart"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/result)
pub fn Attrs::result(self : Attrs, value : String) -> Attrs {
  self.0.attrs["result"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/rotate)
pub fn Attrs::rotate(self : Attrs, value : String) -> Attrs {
  self.0.attrs["rotate"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/rx)
pub fn Attrs::rx(self : Attrs, value : String) -> Attrs {
  self.0.attrs["rx"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/ry)
pub fn Attrs::ry(self : Attrs, value : String) -> Attrs {
  self.0.attrs["ry"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/scale)
pub fn Attrs::scale(self : Attrs, value : String) -> Attrs {
  self.0.attrs["scale"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/seed)
pub fn Attrs::seed(self : Attrs, value : String) -> Attrs {
  self.0.attrs["seed"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/shape-rendering)
pub fn Attrs::shape_rendering(self : Attrs, value : String) -> Attrs {
  self.0.attrs["shape-rendering"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/side)
pub fn Attrs::side(self : Attrs, value : String) -> Attrs {
  self.0.attrs["side"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/slope)
pub fn Attrs::slope(self : Attrs, value : String) -> Attrs {
  self.0.attrs["slope"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/spacing)
pub fn Attrs::spacing(self : Attrs, value : String) -> Attrs {
  self.0.attrs["spacing"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/specularConstant)
pub fn Attrs::specular_constant(self : Attrs, value : String) -> Attrs {
  self.0.attrs["specularConstant"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/specularExponent)
pub fn Attrs::specular_exponent(self : Attrs, value : String) -> Attrs {
  self.0.attrs["specularExponent"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/spreadMethod)
pub fn Attrs::spread_method(self : Attrs, value : String) -> Attrs {
  self.0.attrs["spreadMethod"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/startOffset)
pub fn Attrs::start_offset(self : Attrs, value : String) -> Attrs {
  self.0.attrs["startOffset"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stdDeviation)
pub fn Attrs::std_deviation(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stdDeviation"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stitchTiles)
pub fn Attrs::stitch_tiles(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stitchTiles"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stop-color)
pub fn Attrs::stop_color(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stop-color"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stop-opacity)
pub fn Attrs::stop_opacity(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stop-opacity"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke)
pub fn Attrs::stroke(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-dasharray)
pub fn Attrs::stroke_dasharray(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-dasharray"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-dashoffset)
pub fn Attrs::stroke_dashoffset(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-dashoffset"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-linecap)
pub fn Attrs::stroke_linecap(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-linecap"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-linejoin)
pub fn Attrs::stroke_linejoin(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-linejoin"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-miterlimit)
pub fn Attrs::stroke_miterlimit(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-miterlimit"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-opacity)
pub fn Attrs::stroke_opacity(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-opacity"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/stroke-width)
pub fn Attrs::stroke_width(self : Attrs, value : String) -> Attrs {
  self.0.attrs["stroke-width"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/surfaceScale)
pub fn Attrs::surface_scale(self : Attrs, value : String) -> Attrs {
  self.0.attrs["surfaceScale"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/systemLanguage)
pub fn Attrs::system_language(self : Attrs, value : String) -> Attrs {
  self.0.attrs["systemLanguage"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/tabindex)
pub fn Attrs::tabindex(self : Attrs, value : String) -> Attrs {
  self.0.attrs["tabindex"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/tableValues)
pub fn Attrs::table_values(self : Attrs, value : String) -> Attrs {
  self.0.attrs["tableValues"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/target)
pub fn Attrs::target(self : Attrs, value : String) -> Attrs {
  self.0.attrs["target"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/targetX)
pub fn Attrs::target_x(self : Attrs, value : String) -> Attrs {
  self.0.attrs["targetX"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/targetY)
pub fn Attrs::target_y(self : Attrs, value : String) -> Attrs {
  self.0.attrs["targetY"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/text-anchor)
pub fn Attrs::text_anchor(self : Attrs, value : String) -> Attrs {
  self.0.attrs["text-anchor"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/text-decoration)
pub fn Attrs::text_decoration(self : Attrs, value : String) -> Attrs {
  self.0.attrs["text-decoration"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/text-overflow)
pub fn Attrs::text_overflow(self : Attrs, value : String) -> Attrs {
  self.0.attrs["text-overflow"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/text-rendering)
pub fn Attrs::text_rendering(self : Attrs, value : String) -> Attrs {
  self.0.attrs["text-rendering"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/textLength)
pub fn Attrs::text_length(self : Attrs, value : String) -> Attrs {
  self.0.attrs["textLength"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/to)
pub fn Attrs::to(self : Attrs, value : String) -> Attrs {
  self.0.attrs["to"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/transform)
pub fn Attrs::transform(self : Attrs, value : String) -> Attrs {
  self.0.attrs["transform"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/transform-origin)
pub fn Attrs::transform_origin(self : Attrs, value : String) -> Attrs {
  self.0.attrs["transform-origin"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/type)
pub fn Attrs::type_(self : Attrs, value : String) -> Attrs {
  self.0.attrs["type"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/unicode-bidi)
pub fn Attrs::unicode_bidi(self : Attrs, value : String) -> Attrs {
  self.0.attrs["unicode-bidi"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/values)
pub fn Attrs::values(self : Attrs, value : String) -> Attrs {
  self.0.attrs["values"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/vector-effect)
pub fn Attrs::vector_effect(self : Attrs, value : String) -> Attrs {
  self.0.attrs["vector-effect"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/viewBox)
pub fn Attrs::view_box(self : Attrs, value : String) -> Attrs {
  self.0.attrs["viewBox"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/visibility)
pub fn Attrs::visibility(self : Attrs, value : String) -> Attrs {
  self.0.attrs["visibility"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/white-space)
pub fn Attrs::white_space(self : Attrs, value : String) -> Attrs {
  self.0.attrs["white-space"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/width)
pub fn Attrs::width(self : Attrs, value : String) -> Attrs {
  self.0.attrs["width"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/word-spacing)
pub fn Attrs::word_spacing(self : Attrs, value : String) -> Attrs {
  self.0.attrs["word-spacing"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/writing-mode)
pub fn Attrs::writing_mode(self : Attrs, value : String) -> Attrs {
  self.0.attrs["writing-mode"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/x)
pub fn Attrs::x(self : Attrs, value : String) -> Attrs {
  self.0.attrs["x"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/x1)
pub fn Attrs::x1(self : Attrs, value : String) -> Attrs {
  self.0.attrs["x1"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/x2)
pub fn Attrs::x2(self : Attrs, value : String) -> Attrs {
  self.0.attrs["x2"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/xChannelSelector)
pub fn Attrs::x_channel_selector(self : Attrs, value : String) -> Attrs {
  self.0.attrs["xChannelSelector"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/y)
pub fn Attrs::y(self : Attrs, value : String) -> Attrs {
  self.0.attrs["y"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/y1)
pub fn Attrs::y1(self : Attrs, value : String) -> Attrs {
  self.0.attrs["y1"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/y2)
pub fn Attrs::y2(self : Attrs, value : String) -> Attrs {
  self.0.attrs["y2"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/yChannelSelector)
pub fn Attrs::y_channel_selector(self : Attrs, value : String) -> Attrs {
  self.0.attrs["yChannelSelector"] = value
  self
}

///|
/// [MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/z)
pub fn Attrs::z(self : Attrs, value : String) -> Attrs {
  self.0.attrs["z"] = value
  self
}
