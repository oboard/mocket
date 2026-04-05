# Subscriptions

The `sub` package models **long-lived external signals** that should feed back
into your TEA update loop.

Unlike `Cmd`, which runs once, a `Sub` stays installed until your app stops
returning it.

## Basic shape

In Rabbita, subscriptions are usually returned from the `subscriptions`
callback of a cell.

```mbt nocheck
///|
fn subscriptions(dispatch : Dispatch[Msg], model : Model) -> @sub.Sub {
  if model.running {
    @sub.every(1000, dispatch(Tick))
  } else {
    @sub.none
  }
}
```

## Building subscriptions

Use `none` when nothing should be active:

```moonbit check
///|
test "sub none" {
  let _ : Sub = @sub.none
}
```

Use `batch` to combine multiple subscriptions:

```moonbit check
///|
test "sub batch" {
  let _ : Sub = @sub.batch([none, every(1000, @cmd.none)])
}
```

## Dispatching messages

Event-based subscriptions usually work with `dispatch.map(...)`, just like
HTML event handlers.

```mbt nocheck
///|
enum Msg {
  Resized(ViewPort)
  MouseMoved(Mouse)
}

///|
fn subscriptions(dispatch : Dispatch[Msg], _model : Model) -> @sub.Sub {
  @sub.batch([
    @sub.on_resize(v => dispatch(Resized(v))),
    @sub.on_mouse_move(m => dispatch(MouseMoved(m))),
  ])
}
```





