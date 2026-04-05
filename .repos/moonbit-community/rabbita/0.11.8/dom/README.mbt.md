# DOM API

This package exposes low-level DOM bindings for the JavaScript backend. The API
is intentionally thin and incomplete: it mirrors browser APIs, keeps nullability
explicit, and avoids convenience layers. Most users should prefer the `@html`
package and only drop to `@dom` for imperative interop.

**Warning:** This package is JS-backend only and not guaranteed to stay stable.
Using it may reduce cross-platform compatibility.

## Quick examples

### Query and set attributes

```mbt check
///|
#cfg(target="js")
test {
  let doc = @dom.document()
  if doc.get_element_by_id("hero").to_option() is Some(el) {
    el.set_attribute("data-ready", "true")
  }
}
```

### Add an event listener

```mbt check
///|
#cfg(target="js")
test {
  if @dom.document().get_element_by_id("btn").to_option() is Some(el) {
    el.add_event_listener("click", event => {
      guard event.to_mouse_event() is Some(mouse) else { return }
      let _x = mouse.get_client_x()
      let _y = mouse.get_client_y()
    })
  }
}
```

### Canvas context

```mbt nocheck
///|
test {
  let doc = @dom.document()
  if doc.get_element_by_id("canvas").to_option() is Some(el) &&
    el.to_html_canvas_element() is Some(canvas) &&
    canvas.get_context("2d").to0() {
    ctx.fill_rect(0, 0, 100, 60)
  }
}
```

## Nullability and optional parameters

- Values that can be `null` use `@js.Nullable[T]`. Convert them with
  `to_option()` and pattern match on `Some/None`.
- Optional JS parameters use `@js.Optional[T]` with default
  `@js.Optional::undefined()`.

## Naming conventions and file structure

- Each DOM type and its methods live in a corresponding file.
- Types use `CamelCase`; methods use `snake_case`.
- DOM properties are exposed as `get_*/set_*` methods.
- Overloads are disambiguated with suffixes based on parameter shapes.
- Union types use `@js.UnionN[A, B, ...]`.
- Conversions 
  - Upcasts return the target type directly, use `as_<type>`.
  - Downcasts return `T?` and must be checked, use `to_<type>`.

## Type relationships (partial)

```plaintext
Event <- AnimationEvent
      <- BlobEvent
      <- BeforeUnloadEvent
      <- ClipboardEvent
      <- CloseEvent
      <- CompositionEvent
      <- CustomEvent
      <- UIEvent <- MouseEvent <- DragEvent
                 <- FocusEvent
                 <- InputEvent
                 <- KeyboardEvent
                 <- WheelEvent

EventTarget <- Window
            <- Node <- Document
                    <- DocumentFragment
                    <- Element <- HTMLElement <- HTMLCanvasElement
                                              <- HTMLInputElement
                                              <- HTMLDialogElement
                                              <- HTMLImageElement
                                              <- HTMLMediaElement <- HTMLVideoElement
                               <- SVGElement <- SVGGraphicsElement
                                             <- SVGImageElement
```

## Contribution

Contributions are welcome.

  If you would like to contribute a patch, please follow these
  guidelines:

  - Keep APIs low-level and explicit about nullability.
  - Follow the naming conventions above.
  - Add an MDN link near new extern bindings.
  - Prefer small, focused PRs.

You can also contribute by reporting issues and bugs.
