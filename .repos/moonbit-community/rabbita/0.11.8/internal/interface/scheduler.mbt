///|
pub(open) trait Scheduler {
  // add(Self, &Command) -> Unit = _
  add_cmd(Self, CustomCommand) -> Unit
  add_cmds(Self, Array[CustomCommand]) -> Unit = _
  add_url_changed(Self, @url.Url) -> Unit
}

///|
impl Scheduler with add_cmds(s, xs) {
  xs.each(x => s.add_cmd(x))
}

// ///|
// impl Scheduler with add(s, c) {
//   c.to_array().each(x => s.add_cmd(x))
// }
