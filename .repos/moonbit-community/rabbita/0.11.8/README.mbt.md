# Rabbita

A declarative, functional web UI framework inspired by The Elm Architecture.

This project was previously named `Rabbit-TEA` and is now renamed to `rabbita` .

## Features

* Predictable flow 

  State changes follow a single, predictable update path, with explicit side‑effect management.

* Strict Types

  Rigorous types. No `Any` sprawl. No stringly-typed APIs.

* Balanced bundle size

  ~15 KB min+gzip, includes streaming VDOM diff and the MoonBit standard library (DCE via moonc).

* Modular

  Use `Cell` to split logic and reuse stateful views. Skip diff and patching for non-dirty cells.

## Quick Start

Use the [rabbita-template](https://github.com/moonbit-community/rabbita-template) to get started quickly.

## Examples

### Counter 

```mbt check
///|
using @html {div, h1, button}

///|
#cfg(target="js")
test {
  struct Model {
    count : Int
  }
  enum Msg {
    Inc
    Dec
  }
  let app = @rabbita.simple_cell(
    model={ count: 0 },
    update=(msg, model) => {
      let { count } = model
      match msg {
        Inc => { count: count + 1 }
        Dec => { count: count - 1 }
      }
    },
    view=(dispatch, model) => {
      div([
        h1("\{model.count}"),
        button(on_click=dispatch(Inc), "+"),
        button(on_click=dispatch(Dec), "-"),
      ])
    },
  )
  new(app).mount("main")
}
```

### Multiple cells

Each cell maintains its own model, view, and update logic, and only dirty cells
need VDOM diffing and patching.

```moonbit check
///|
using @html {fragment, input, nothing, ul, li, p}

///|
using @list {type List, empty}

///|
/// The todo plan
fn plan(name : String) -> Cell {
  struct Model {
    value : String
    items : Map[String, Bool]
  }
  enum Msg {
    Add
    Change(String)
    Done(String)
  }
  @rabbita.simple_cell(
    model={ value: "", items: {} },
    update=(msg, model) => {
      let { value, items } = model
      match msg {
        Add => { value: "", items: items..set(value, false) }
        Done(key) => { ..model, items: items..set(key, true) }
        Change(value) => { ..model, value, }
      }
    },
    view=(dispatch, model) => {
      let { value, items } = model
      let items = items.map((todo, done) => {
        let text_style = if done { "text-decoration: line-through" } else { "" }
        li(style=[text_style], [
          p(todo),
          button(on_click=dispatch(Done(todo)), "done"),
        ])
      })
      div(style=["border: 1px solid black", "padding: 1em"], [
        h1(name),
        ul(items),
        input(
          input_type=Text,
          value~,
          on_change=s => dispatch(Change(s)),
          nothing,
        ),
        button(on_click=dispatch(Add), "add"),
      ])
    },
  )
}

///|
/// Main app
#cfg(target="js")
test {
  struct Model {
    plans : List[Cell]
  }
  enum Msg {
    NewPlan
  }
  let app = @rabbita.simple_cell(
    model={ plans: empty() },
    update=(msg, model) => {
      let id = model.plans.length()
      match msg {
        NewPlan => { plans: model.plans.add(plan("plan \{id}")) }
      }
    },
    view=(dispatch, model) => {
      fragment([
        div(model.plans.map(x => x.view())),
        button(on_click=dispatch(NewPlan), "new plan"),
      ])
    },
  )
  @rabbita.new(app).mount("app")
}
```

`Cell` is an opaque model: it is still managed by the outer model, but internal 
details are hidden. `Cell::view()` is a pure function that maps state to HTML. 

Unlike the hooks-style mental model, a cell's lifecycle is explicit: 
if its view is not present in the real DOM, the cell is inactive and messages to
it are ignored. If the model is removed from the outer model, the cell is destroyed
by the garbage collector.

# Used By

[mooncakes.io](https://mooncakes.io)
