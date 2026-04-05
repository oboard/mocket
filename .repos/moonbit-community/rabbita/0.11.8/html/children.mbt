///|
pub trait IsChildren {
  to_children(Self) -> @runtime.Children[VNode]
}

///|
pub impl IsChildren for Html with to_children(html) {
  Array([html.0])
}

///|
pub impl IsChildren for String with to_children(str) {
  Array([text(str).0])
}

///|
pub impl IsChildren for Map[String, Html] with to_children(self) {
  Map(self.map((_, v) => v.0))
}

///|
pub impl IsChildren for Array[Html] with to_children(self) {
  Array(self.map(x => x.0))
}

///|
pub impl IsChildren for @list.List[Html] with to_children(self) {
  Array(self.map(x => x.0).to_array())
}

// ///|
// pub impl[H : IsHtml] IsChildren for Array[H] with to_children(self) {
//   Array(self.map(x => x.to_html()))
// }

///|
pub impl IsChildren for @runtime.Children[VNode] with to_children(children) {
  children
}
