# Asynchronous programming library for MoonBit

This library provides basic asynchronous IO functionality for MoonBit,
as well as useful asynchronous programming facilities.
Currently, this library only supports native/LLVM backends on Linux/MacOS.

API document is available at <https://mooncakes.io/docs/moonbitlang/async>.
You can also find small examples in `examples`,
these examples can be run via `moon run -C examples examples/<example-name>` in project root.
Youn can find a brief introduction to some examples in `examples/README.md`,
including the topics each example covers.

WARNING: this library is current experimental, API is subject to future change.

## Installation
In your MoonBit project root, run:
```bash
moon add moonbitlang/async@0.17.0
```
This library provides the following packages:

- `moonbitlang/async`: most basic asynchronous operations
- `moonbitlang/async/socket`: TCP and UDP socket
- `moonbitlang/async/tls`: TLS support via OpenSSL
- `moonbitlang/async/stdio`: operations on standard output channels
- `moonbitlang/async/pipe`: operations on pipes
- `moonbitlang/async/fs`: file system operations, such as file IO and directory reading
- `moonbitlang/async/process`: spawning system process
- `moonbitlang/async/aqueue`: asynchronous queue data structure for inter-task communication
- `moonbitlang/async/semaphore`: semaphore for concurrency control
- `moonbitlang/async/cond_var`: condition variable with broadcasting support
- `moonbitlang/async/io`: generic IO abstraction & utilities, such as buffering
- `moonbitlang/async/http`: HTTP client and server support. Features:
    - HTTPS client support
    - `CONNECT` based HTTP/HTTPS proxy support
- `moonbitlang/async/websocket`: WebSocket client and server support. Features:
    - TLS encrypted WebSocket (`wss://`) support
    - `CONNECT` based HTTP/HTTPS proxy support
    - native integration with `moonbitlang/async/http`

To use these packages, add them to the `import` field of `moon.pkg.json`.

## Features

- [X] TCP/UDP socket
- [X] DNS resolution
- [X] TLS support
- [X] HTTP support
- [X] timer
- [X] pipe
- [X] asynchronous file system operations
- [X] process manipulation
- [ ] signal handling
- [ ] file system watching
- [X] structured concurrency
- [X] cooperative multi tasking
- [X] IO worker thread
- [X] native integration with the MoonBit language
- [X] Linux support (`epoll`)
- [X] MacOS support (`kqueue`)
- [X] Windows support (`IOCP`)
- [ ] WASM backend
- [X] Javascript backend
    - [X] integration with JavaScript promise and Web API `ReadableStream`
    - [X] all IO-independent API, including:
        - `moonbitlang/async`
        - `moonbitlang/async/io`
        - `moonbitlang/async/aqueue`
        - `moonbitlang/async/semaphore`
        - `moonbitlang/async/cond_var`
    - [X] HTTP Client API support in `@http` using fetch API
    - [ ] implement other IO primitives in JavaScript using Node.js


## Structured concurrency and error propagation
`moonbitlang/async` features *structured concurrency*.
In `moonbitlang/async`, every asynchronous task must be spawned in a *task group*.
Task groups can be created with the `with_task_group` function

```moonbit
async fn[X] with_task_group(async (TaskGroup[X]) -> X)  -> X
```

When `with_task_group` returns,
it is guaranteed that all tasks spawned in the group already terminate,
leaving no room for orphan task and resource leak.

If any child task in a task group fail with error,
all other tasks in the group will be cancelled.
So there will be no silently ignored error.

For more behavior detail and useful API, consult the API document.

## Task cancellation
In `moonbitlang/async`, all asynchronous operations are by default cancellable.
So no need to worry about accidentally creating uncancellable task.

In `moonbitlang/async`, when a task is cancelled,
it will receive an error at where it suspended.
The cancelled task can then perform cleanup logic using `try .. catch`.
Since most asynchronous operations may throw other error anyway,
correct error handling automatically gives correct cancellation handling,
so most of the time correct cancellation handling just come for free in `moonbitlang/async`.

Currently, it is not allowed to perform other asynchronous operation after a task is cancelled.
Those operations will be cancelled immediately if current task is already cancelled.
Spawn a task in some parent context if asynchronous cleanup is necessary.

## Caveats

Currently, `moonbitlang/async` features a single-threaded, cooperative multitasking model.
With this single-threaded model,
code without suspension point can always be considered atomic.
So no need for expensive lock and less bug.
However, this model also come with some caveats:

- task scheduling can only happen when current task suspend itself,
by performing some asynchronous IO operation or manually calling `@async.pause`.
If you perform heavy computation loop without pausing from time to time,
the whole program will be blocked until the loop terminates,
and other task will not get executed before that.
Similarly, performing blocking IO operation **not** provided by `moonbitlang/async`
may block the whole program as well

- in the same way, task cancellation can only happen when a task is in suspended state
(blocked by IO operation or manually `pause`'ed)

- although internally `moonbitlang/async` may use OS threads to perform some IO job,
user code can only utilize one hardware processor

There are several other points to notice when using this library:

- At most one task can read/write to socket etc. at anytime, to avoid race condition.
If multiple reader/writer is desired,
you should create a dedicated worker task for reading/writing
and use `@async.Queue` to distribute/gather data
