# Runtime

This package is the internal engine behind Rabbita's TEA-style update loop.
Application code should normally use the public APIs from `@rabbita`, not this
package directly.

## Core Concepts

`internal/runtime` defines the low-level pieces that coordinate state updates,
effects, and DOM patching:

- `Cmd`: deferred work handled by the scheduler.
- `Scheduler`: runtime trait that can enqueue commands and route URL events.
- `IsCell`: stateful unit with `step`, `view`, and `flags`.
- `Sandbox`: concrete scheduler and render loop implementation.
- `VNode` / `Props` / `Children`: virtual DOM data model and patching helpers.

## Update and Render Pipeline

The runtime executes updates in two phases: message draining and frame flushing.

1. A dispatch function returns `Cmd::Message(id, send)`.
2. `Scheduler::add` executes the command:
   - `Empty`: no-op
   - `Batch`: enqueue each command recursively
   - `Effect`: run callback immediately with `&Scheduler`
   - `Message`: call `send()`, push `id` into the queue
3. `Sandbox::drain` processes queued ids in FIFO order:
   - looks up the live cell by id
   - runs `cell.step(self)`
   - marks the id dirty
4. `Sandbox::flush` schedules one `requestAnimationFrame` callback:
   - for each dirty live instance, compute new `view()`
   - run VDOM diff and patch DOM
   - clear dirty flags/set after commit

This keeps model updates synchronous and deterministic while keeping side
effects explicit.

## Commands

`Cmd` is an internal enum. 

The key rule is that update returns commands; effects are executed by runtime,
not directly inside `update`.

## Cells, Identity, and Liveness

Each cell has `Flags`:

- `id`: stable runtime id
- `dirty`: whether the cell needs rerender

`Sandbox.live_map` tracks all currently attached instances for each cell id.
When a subtree is removed, `drop_live_subtree` removes stale instances from `live_map`. 
Messages for detached cells are ignored because they no longer resolve in `live_map`.

## Link Interception and Routing Hooks

`VNode::link` uses a special internal tag to install a captured click listener.
At insert time it becomes an actual `<a>` element. The listener classifies URLs:

- same origin -> `@url.Internal(url)`
- different origin -> `@url.External(href)`

When `App::with_route(url_request=...)` is configured, it dispatches
`add_url_request`. Without that callback, the listener keeps native `<a>`
navigation behavior (no interception).

## Design Notes

- Update execution is synchronous per message, which preserves a single source
  of truth for model transitions.
- Async work is represented as `Cmd` and re-enters the loop as messages.
- Rendering is batched to animation frames to avoid repeated DOM work within a
  burst of updates.



