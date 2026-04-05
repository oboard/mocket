//|

///|
// #visibility(change_to="readonly", "Create a dispatcher from function is deprecated, use `Dispatch::map` method to compose function instead. Hint: `div(on_mousedown=dispatch.map(mouse => Msg(mouse)))")
pub(all) struct Dispatch[Msg]((Msg) -> Cmd)

///|
pub fn[A, B] Dispatch::map(self : Self[A], f : (B) -> A) -> Self[B] {
  b => self(f(b))
}

///|
/// internal use only
#doc(hidden)
pub fn[Msg] make_dispatcher(
  id : @interface.Id,
  inbox : @queue.Queue[Msg],
) -> Dispatch[Msg] {
  // carry the drain (which own model and update) in message will cause memory leak in RC
  msg => [Message(id, () => inbox.push(msg))]
}
