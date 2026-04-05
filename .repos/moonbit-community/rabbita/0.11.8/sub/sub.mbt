///|
using @interface {trait Scheduler}

///|
using @common {type Keyboard, type Mouse, type Scroll, type Viewport}

///|
using @cmd {type Cmd}

///|
/// A long-lived subscription managed by the Rabbita runtime.
///
/// Use subscriptions to listen to external signals such as timers, window
/// resize, scrolling, keyboard input, or visibility changes.
struct Sub(Map[String, @interface.CustomSubscription])

///|
fn custom_subscription(key : String, load : (&Scheduler) -> () -> Unit) -> Sub {
  Map::from_array([(key, load)])
}

///|
pub impl @interface.Subscription for Sub with to_map(self) {
  self.0
}

///|
fn add_cmd(scheduler : &Scheduler, cmd : Cmd) -> Unit {
  scheduler.add_cmds(cmd.to_array())
}

///|
fn event_subscription(
  key : String,
  target : @dom.EventTarget,
  event_name : String,
  handler : (@dom.Event) -> Cmd,
) -> Sub {
  custom_subscription(key, scheduler => {
    let listener : @dom.Listener = event => add_cmd(scheduler, handler(event))
    target.add_event_listener(event_name, listener)
    fn() { target.remove_event_listener(event_name, listener) }
  })
}

///|
fn keyboard_from_dom(event : @dom.KeyboardEvent) -> Keyboard {
  Keyboard::new(
    key=event.key(),
    code=event.code(),
    alt_key=event.alt_key(),
    ctrl_key=event.ctrl_key(),
    shift_key=event.shift_key(),
    meta_key=event.meta_key(),
    is_composing=event.is_composing(),
    repeat=event.repeat(),
    location=event.location(),
  )
}

///|
fn mouse_from_dom(event : @dom.MouseEvent) -> Mouse {
  Mouse::new(
    screen={ x: event.get_screen_x(), y: event.get_screen_y() },
    offset={ x: event.get_offset_x(), y: event.get_offset_y() },
    client={ x: event.get_client_x(), y: event.get_client_y() },
  )
}

///|
fn window_scroll() -> Scroll {
  let root = @dom.document().query_selector("html").unwrap()
  Scroll::new(
    offset={ x: @dom.window().scroll_x(), y: @dom.window().scroll_y() },
    width=root.get_scroll_width().to_int(),
    height=root.get_scroll_height().to_int(),
  )
}

///|
/// Repeatedly enqueue `cmd` every `ms` milliseconds.
pub fn every(ms : Int, cmd : @cmd.Cmd) -> Sub {
  custom_subscription("every(\{ms})", scheduler => {
    let id : Int = @dom.window().set_interval(() => add_cmd(scheduler, cmd), ms)
    fn() { @dom.window().clear_interval(id) }
  })
}

///|
/// Subscribe to window resize events.
///
/// The handler receives the latest viewport width and height.
pub fn on_resize(msg : @cmd.Dispatch[Viewport]) -> Sub {
  event_subscription("on_resize", @dom.window().as_event_target(), "resize", event => {
    ignore(event)
    msg({
      width: @dom.window().inner_width(),
      height: @dom.window().inner_height(),
    })
  })
}

///|
/// Subscribe to `requestAnimationFrame` ticks.
///
/// The handler receives the browser timestamp for each frame while the
/// subscription is active.
pub fn on_animation_frame(msg : @cmd.Dispatch[Double]) -> Sub {
  custom_subscription("on_animation_frame", scheduler => {
    let mut active = true
    let mut request_id : Double? = None

    fn queue_next() {
      request_id = Some(
        @dom.window().request_animation_frame(timestamp => {
          guard active else { return }
          add_cmd(scheduler, msg(timestamp))
          queue_next()
        }),
      )
    }

    queue_next()
    fn() {
      active = false
      guard request_id is Some(id) else { return }
      @dom.window().cancel_animation_frame(id)
    }
  })
}

///|
/// Subscribe to document `keydown` events.
///
/// The handler receives a normalized `Keyboard` value from `@common`.
pub fn on_key_down(msg : @cmd.Dispatch[Keyboard]) -> Sub {
  event_subscription(
    "on_key_down",
    @dom.document().as_event_target(),
    "keydown",
    event => msg(keyboard_from_dom(event.to_keyboard_event().unwrap())),
  )
}

///|
/// Subscribe to document `keyup` events.
///
/// The handler receives a normalized `Keyboard` value from `@common`.
pub fn on_key_up(msg : @cmd.Dispatch[Keyboard]) -> Sub {
  event_subscription("on_key_up", @dom.document().as_event_target(), "keyup", event => {
    msg(keyboard_from_dom(event.to_keyboard_event().unwrap()))
  })
}

///|
/// Subscribe to document visibility changes.
///
/// The handler receives `true` when the document is hidden, and `false`
/// when it becomes visible again.
pub fn on_visibility_change(msg : @cmd.Dispatch[Bool]) -> Sub {
  event_subscription(
    "on_visibility_change",
    @dom.document().as_event_target(),
    "visibilitychange",
    _ => msg(@dom.document().hidden()),
  )
}

///|
/// Subscribe to document `mousemove` events.
///
/// The handler receives a normalized `Mouse` value from `@common`.
pub fn on_mouse_move(msg : @cmd.Dispatch[Mouse]) -> Sub {
  event_subscription(
    "on_mouse_move",
    @dom.document().as_event_target(),
    "mousemove",
    event => msg(mouse_from_dom(event.to_mouse_event().unwrap())),
  )
}

///|
/// Subscribe to window scroll events.
///
/// This reports page-level scrolling on `window`, not scrolling of an inner
/// element. The handler receives the current scroll offset and document scroll
/// size as a `Scroll` value.
pub fn on_scroll(msg : @cmd.Dispatch[Scroll]) -> Sub {
  event_subscription("on_scroll", @dom.window().as_event_target(), "scroll", event => {
    ignore(event)
    msg(window_scroll())
  })
}

///|
/// A subscription that does nothing.
pub let none : Sub = {}

///|
/// Combine multiple subscriptions into one.
///
/// If multiple subscriptions use the same internal key, the later one wins.
pub fn batch(xs : Array[Sub]) -> Sub {
  let r = {}
  for x in xs {
    for k, v in x.0 {
      r[k] = v
    }
  }
  r
}
