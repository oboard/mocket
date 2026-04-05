///|
priv struct Link {
  mut val : Instance?
}

///|
fn Link::detach(s : Self) -> Unit {
  s.val = None
}
