///|
pub(open) trait Command {
  to_array(Self) -> Array[CustomCommand]
}

///|
pub(all) enum CustomCommand {
  Immediately(OnExecute)
  AfterRender(OnExecute)
  Message(Id, () -> Unit)
}

///|
type OnExecute = (&Scheduler) -> Unit
