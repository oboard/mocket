# oboard/mocket

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A//mooncakes.io/assets/oboard/mocket/resource.json&query=%24.meta_info.version&label=mooncakes&color=yellow)](https://mooncakes.io/docs/oboard/mocket) [![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/oboard/mocket/check.yaml)](https://github.com/oboard/mocket/actions/workflows/check.yaml) [![License](https://img.shields.io/github/license/oboard/mocket)](https://github.com/oboard/mocket/blob/main/LICENSE)

A web framework for MoonBit.

[👉 Documentation](https://mocket.oboard.fun/)

## Quick Start

```moonbit
fn main {
  let app = @mocket.new()
  app.get("/", _ => "Hello, Mocket!")
  app.serve(port=4000)
}
```

Mocket is being refactored toward a native-first runtime built on
`moonbitlang/async`.

### Native Backend

Set the backend of MoonBit to `native` in `Visual Studio Code`

Command: `MoonBit: Select Backend` -> `native`

```bash
moon run src/example --target native
```

Then visit http://localhost:4000

### Async Native Runtime

The preferred native runtime entry point is now `serve_async`, which runs on
top of `moonbitlang/async/http`.

Native `fetch` also runs on `moonbitlang/async/http`, so the framework no
longer depends on the old C-based transport bridge.

```moonbit
async fn main {
  let app = @mocket.new()
  app.get("/", _ => "Hello, async Mocket!")
  app.serve_async(port=4000)
}
```

On native, `serve` is now a synchronous compatibility wrapper over the async
runtime.

## Usage

Minimum Example: https://github.com/oboard/mocket_example

🙌快来吧！🙌

QQ 群号：**949886784**

![QQ 群](qrcode.jpg)
