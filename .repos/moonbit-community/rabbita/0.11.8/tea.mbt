///|
priv struct TypedCell[Model, Msg] {
  mut has_init : Bool
  model : Ref[Model]
  dispatch : @cmd.Dispatch[Msg]
  inbox : @queue.Queue[Msg]
  update : (Dispatch[Msg], Msg, Model) -> (Cmd, Model)
  view : (Dispatch[Msg], Model) -> @html.Html
  subscriptions : ((Dispatch[Msg], Model) -> @sub.Sub)?
  mut sub_map : SubscriptionMap
  flags : @runtime.Flags
}

///|
type SubscriptionMap = Map[String, () -> Unit]

///|
/// Message dispatcher type used by a `Cell`.
///
/// Calling `dispatch(msg)` returns a `Cmd` that enqueues `msg` into the cell's
/// update loop.
pub type Dispatch[Msg] = @cmd.Dispatch[Msg]

///|
impl[Model, Msg] @runtime.IsCell for TypedCell[Model, Msg] with init(
  self,
  scheduler,
) {
  guard !self.has_init else { return }
  self.has_init = true
  if self.subscriptions is Some(subscriptions) {
    let subs = subscriptions(self.dispatch, self.model.val).to_map()
    for key, sub in subs {
      self.sub_map[key] = sub(scheduler)
    }
  }
}

///|
fn diff_subs(
  old_subs : SubscriptionMap,
  new_subs : Map[String, @interface.CustomSubscription],
  scheduler : &@interface.Scheduler,
) -> SubscriptionMap {
  let sub_map = {}
  for key, dispose in old_subs {
    if !new_subs.contains(key) {
      dispose()
    } else {
      sub_map[key] = dispose
    }
  }
  for key, sub in new_subs {
    if !old_subs.contains(key) {
      sub_map[key] = sub(scheduler)
    }
  }
  sub_map
}

///|
impl[Model, Msg] @runtime.IsCell for TypedCell[Model, Msg] with step(
  self,
  scheduler,
) {
  if self.inbox.pop() is Some(msg) {
    let (cmd, model) = (self.update)(self.dispatch, msg, self.model.val)
    if self.subscriptions is Some(subscriptions) {
      let new_subs = subscriptions(self.dispatch, model).to_map()
      let old_subs = self.sub_map
      self.sub_map = diff_subs(old_subs, new_subs, scheduler)
    }
    self.model.val = model
    scheduler.add_cmds(cmd.to_array())
    self.flags.mark_dirty()
  } else {
    // violate the invariant
  }
}

///|
impl[Model, Msg] @runtime.IsCell for TypedCell[Model, Msg] with view(self) {
  (self.view)(self.dispatch, self.model.val).0
}

///|
impl[Model, Msg] @runtime.IsCell for TypedCell[Model, Msg] with flags(self) {
  self.flags
}

///|
/// A cell that encapsulates model, update, and view.
struct Cell(&@runtime.IsCell)

///|
/// Render this cell as `Html`.
pub fn Cell::view(self : Self) -> Html {
  Html::from_vnode(@runtime.VNode::slot(self.0))
}

///|
/// Create a stateful cell with full `model`/`update`/`view` functionality.
///
/// Type parameters:
///
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
///
/// Parameters:
///
/// - `model : Model`:
///    initial `Model` value of the cell.
/// 
/// - `update : (Dispatch[Msg], Msg,Model) -> (Cmd,Model)`:
///    Describe how to compute new `Model` from `Msg` and old `Model`. 
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
/// 
/// - `view : (Dispatch[Msg], Model) -> Html`:
///    Describe how to compute `Html` from `Model`.
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
///
/// ## The update loop
///
/// ```text
/// ┌─────────────────┐
/// │                 ▼
/// │            ┌──────────┐
/// │            │   user   │
/// │            └────┬─────┘
/// │                 │ msg,model
/// │                 ▼
/// │           ┌────────────┐   msg,model
/// │           │  update()  │◄────────────┐
/// │           └──┬───────┬─┘             │
/// │    none,model│       │               │
/// │              ▼       │               │
/// │         ┌────────┐   │cmd,model      │
/// │         │ view() │   │               │
/// │         └────┬───┘   │               │
/// │              │       │               │
/// │          html│       ▼               │
/// │              │   ┌─────────┐         │
/// └──────────────┘   │ runtime │─────────┘
///                    └─────────┘
/// ```
/// 
/// This update loop is a bit more complex than `simple_cell`, but follows the
/// same `model -> update -> view` flow.
///
/// The difference is that `update` also returns a command representing a managed
/// side effect. That side effect is executed by the runtime and may produce
/// another message.
///
pub fn[Model, Msg] cell(
  model~ : Model,
  update~ : (Dispatch[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Dispatch[Msg], Model) -> Html,
  subscriptions? : (Dispatch[Msg], Model) -> @sub.Sub,
) -> Cell {
  let flags = @runtime.Flags::new()
  let inbox = @queue.Queue::new()
  let dispatch = @cmd.make_dispatcher(flags.id, inbox)
  let model = @ref.new(model)
  Cell({
    has_init: false,
    inbox,
    view,
    update,
    dispatch,
    model,
    flags,
    subscriptions,
    sub_map: {},
  })
}

///|
/// Create a cell and also return its `Dispatch`.
///
/// This is useful when messages need to be sent from outside.
/// 
/// Type parameters:
///
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
///
/// Parameters:
///
/// - `model : Model`:
///    initial `Model` value of the cell.
/// 
/// - `update : (Dispatch[Msg], Msg,Model) -> (Cmd,Model)`:
///    Describe how to compute new `Model` from `Msg` and old `Model`. 
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
/// 
/// - `view : (Dispatch[Msg], Model) -> Html`:
///    Describe how to compute `Html` from `Model`.
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
///
/// ## The update loop
///
/// ```text
/// ┌─────────────────┐
/// │                 ▼
/// │            ┌──────────┐
/// │            │   user   │
/// │            └────┬─────┘
/// │                 │ msg,model
/// │                 ▼
/// │           ┌────────────┐   msg,model
/// │           │  update()  │◄────────────┐
/// │           └──┬───────┬─┘             │
/// │    none,model│       │               │
/// │              ▼       │               │
/// │         ┌────────┐   │cmd,model      │
/// │         │ view() │   │               │
/// │         └────┬───┘   │               │
/// │              │       │               │
/// │          html│       ▼               │
/// │              │   ┌─────────┐         │
/// └──────────────┘   │ runtime │─────────┘
///                    └─────────┘
/// ```
/// 
/// This update loop is a bit more complex than `simple_cell`, but follows the
/// same `model -> update -> view` flow.
///
/// The difference is that `update` also returns a command representing a managed
/// side effect. That side effect is executed by the runtime and may produce
/// another message.
///
pub fn[Model, Msg] cell_with_dispatch(
  model~ : Model,
  update~ : (Dispatch[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Dispatch[Msg], Model) -> Html,
  subscriptions? : (Dispatch[Msg], Model) -> @sub.Sub,
) -> (Dispatch[Msg], Cell) {
  let flags = @runtime.Flags::new()
  let inbox = @queue.Queue::new()
  let dispatch = @cmd.make_dispatcher(flags.id, inbox)
  let model = @ref.new(model)
  (
    dispatch,
    Cell({
      has_init: false,
      inbox,
      view,
      update,
      dispatch,
      model,
      flags,
      subscriptions,
      sub_map: {},
    }),
  )
}

///|
/// Create a cell with simplified `model`/`update`/`view`.
/// 
/// Type parameters:
/// 
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
/// 
/// Parameters:
/// 
/// - `model : Model`: initial Model value of the cell.
/// - `update : (Msg, Model) -> Model`: describe how to compute new Model from Msg and old Model.
/// - `view : (Dispatch[Msg], Model) -> Html`: describes how to render Html from Model.
///   This callback also receives a dispatch argument, which converts a Msg
///   into a Cmd.
/// 
/// ## The update loop
///
/// ```text
///    ┌──────┐
///    │ user │◀─────────┐
///    └──────┘          │
///        │ msg, model  │
///        ▼             │
///  ┌──────────┐        │
///  │ update() │        │ html
///  └──────────┘        │
///        │ model       │
///        ▼             │
///   ┌────────┐         │
///   │ view() │─────────┘
///   └────────┘
/// ```
/// 
/// At startup, the initial `model` is rendered as `Html` by `view`. The rendered 
/// HTML can include message-producing command, for example:
/// 
/// ```moonbit nocheck
/// button(on_click=dispatch(MyMsg), "click me")
/// ```
///
/// When the user clicks the button, `MyMsg` is sent to `update` with the current
/// model. `update` then computes the next model from that message, and the new
/// model is rendered again by `view`.
/// 
/// ## Example 
/// 
/// ```moonbit check
/// test "counter" {
///   struct Model {
///     count : Int
///   }
///   enum Msg {
///     Click
///   }
///   let app = @rabbita.simple_cell(
///     model={ count: 0 },
///     update=(msg, model) => {
///       match msg {
///         Click => { count: model.count + 1 }
///       }
///     },
///     view=(dispatch, model) => {
///       div([
///         h1("You clicked \{model.count} times."),
///         button(on_click=dispatch(Click), "+"),
///       ])
///     },
///   )
///   ignore(app) // use `new(app).mount("id")` in client
/// }
/// ```
pub fn[Model, Msg] simple_cell(
  model~ : Model,
  update~ : (Msg, Model) -> Model,
  view~ : (Dispatch[Msg], Model) -> Html,
) -> Cell {
  cell(model~, update=(_, msg, model) => (none, update(msg, model)), view~)
}

///|
pub fn[Model, Msg] simple_cell_with_dispatch(
  model~ : Model,
  update~ : (Msg, Model) -> Model,
  view~ : (Dispatch[Msg], Model) -> Html,
  subscriptions? : (Dispatch[Msg], Model) -> @sub.Sub,
) -> (Dispatch[Msg], Cell) {
  let flags = @runtime.Flags::new()
  let inbox = @queue.Queue::new()
  let dispatch = @cmd.make_dispatcher(flags.id, inbox)
  let model = @ref.new(model)
  (
    dispatch,
    Cell({
      has_init: false,
      inbox,
      view,
      update: (_, msg, model) => (none, update(msg, model)),
      dispatch,
      model,
      flags,
      subscriptions,
      sub_map: {},
    }),
  )
}

///|
/// Create a static cell that always renders the same `Html`.
///
/// Rather than use `static_cell`, it's recommend to wrap a function that return html directly:
/// 
/// ```moonbit nocheck
/// fn button(text : String, on_click~ : Cmd) -> Html {
///   @html.button(style=["..."], on_click~, text)
/// }
/// ```
pub fn static_cell(html : Html) -> Cell {
  cell(model=(), update=fn(_, _ : Unit, _ : Unit) { (none, ()) }, view=fn(
    _,
    _,
  ) {
    html
  })
}
