///|
pub(open) trait IsCell {
  init(Self, &@interface.Scheduler) -> Unit
  step(Self, &@interface.Scheduler) -> Unit
  view(Self) -> VNode
  flags(Self) -> Flags
}

///|
pub(all) struct Flags {
  id : @interface.Id
  mut dirty : Bool
  mut attach_count : Int
}

///|
pub fn Flags::id(self : Self) -> Id {
  self.id
}

///|
pub fn Flags::new() -> Flags {
  { id: @interface.Id::new(), dirty: false, attach_count: 0 }
}

///|
pub fn Flags::mark_dirty(s : Self) -> Unit {
  s.dirty = true
}
