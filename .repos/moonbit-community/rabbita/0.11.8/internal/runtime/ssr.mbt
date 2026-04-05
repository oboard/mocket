///|
fn write_escaped_text(buf : StringBuilder, value : String) -> Unit {
  for c in value.iter() {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
}

///|
fn write_escaped_attr_value(buf : StringBuilder, value : String) -> Unit {
  for c in value.iter() {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      '\'' => buf.write_string("&#39;")
      _ => buf.write_char(c)
    }
  }
}

///|
fn write_attr(buf : StringBuilder, name : String, value : String) -> Unit {
  buf.write_char(' ')
  buf.write_string(name)
  buf.write_string("=\"")
  write_escaped_attr_value(buf, value)
  buf.write_char('"')
}

///|
fn write_styles_attr(
  buf : StringBuilder,
  attrs : Map[String, String],
  styles : Map[String, String],
) -> Unit {
  if !attrs.contains("style") && styles.is_empty() {
    return
  }
  buf.write_string(" style=\"")
  let mut need_separator = false
  if attrs.get("style") is Some(style_text) {
    write_escaped_attr_value(buf, style_text)
    need_separator = !style_text.is_empty() && !style_text.has_suffix(";")
  }
  for name, value in styles {
    if need_separator {
      buf.write_char(';')
    }
    buf.write_string(name)
    buf.write_char(':')
    write_escaped_attr_value(buf, value)
    need_separator = true
  }
  buf.write_char('"')
}

///|
fn write_variant_text(buf : StringBuilder, value : @variant.Variant) -> Unit {
  match value {
    Boolean(v) => write_escaped_text(buf, v.to_string())
    Integer(v) => write_escaped_text(buf, v.to_string())
    Floating(v) => write_escaped_text(buf, v.to_string())
    String(v) => write_escaped_text(buf, v)
  }
}

///|
fn write_property_attrs(
  buf : StringBuilder,
  attrs : Map[String, String],
  props : Map[String, @variant.Variant],
) -> Unit {
  for name, value in props {
    if name == "textContent" ||
      name == "innerHTML" ||
      name == "style" ||
      attrs.contains(name) {
      continue
    }
    match value {
      Boolean(v) =>
        if v {
          buf.write_char(' ')
          buf.write_string(name)
        }
      Integer(v) => write_attr(buf, name, v.to_string())
      Floating(v) => write_attr(buf, name, v.to_string())
      String(v) => write_attr(buf, name, v)
    }
  }
}

///|
fn vnode_to_string(buf : StringBuilder, vnode : VNode) -> Unit {
  match vnode {
    Elem(tag, props, children, namespace_uri=ns) => {
      let tag = if tag == CAPTURED_LINK_TAG { "a" } else { tag }
      let { attrs, props, styles, .. } = props

      buf.write_char('<')
      buf.write_string(tag)

      if ns is Some(namespace_uri) && tag == "svg" && !attrs.contains("xmlns") {
        write_attr(buf, "xmlns", namespace_uri)
      }
      for name, value in attrs {
        if name == "innerHTML" || name == "style" {
          continue
        }
        write_attr(buf, name, value)
      }
      write_styles_attr(buf, attrs, styles)
      write_property_attrs(buf, attrs, props)
      buf.write_char('>')
      if props.get("innerHTML") is Some(String(raw_html)) {
        buf.write_string(raw_html)
      }
      if props.get("textContent") is Some(text_content) {
        write_variant_text(buf, text_content)
      }
      children_to_string(buf, children)

      buf.write_string("</")
      buf.write_string(tag)
      buf.write_char('>')
    }
    Text(s) => write_escaped_text(buf, s)
    Frag(c) => children_to_string(buf, Array(c))
    Slot(cell) => vnode_to_string(buf, cell.view())
  }
}

///|
fn children_to_string(buf : StringBuilder, children : Children[VNode]) -> Unit {
  match children {
    Array(arr) =>
      for child in arr {
        vnode_to_string(buf, child)
      }
    Map(mp) =>
      for _, child in mp {
        vnode_to_string(buf, child)
      }
  }
}

///|
pub fn server_side_render(root : &IsCell) -> String {
  let vnode = root.view()
  let buf = StringBuilder::new()
  vnode_to_string(buf, vnode)
  buf.to_string()
}
