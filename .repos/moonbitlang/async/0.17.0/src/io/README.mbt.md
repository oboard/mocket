# I/O API (`@moonbitlang/async/io`)

Asynchronous I/O abstraction for MoonBit. This package provides fundamental abstractions for reading from and writing to various data sources, including buffering capabilities, backpressure-aware copies, and helpers that pair naturally with other MoonBit async packages such as `@async`, `@socket`, and `@fs`.

## Table of Contents

- [Quick Start](#quick-start)
- [Core Traits](#core-traits)
  - [Reader Trait](#reader-trait)
  - [Writer Trait](#writer-trait)
  - [Data Trait](#data-trait)
- [Buffered I/O](#buffered-io)
  - [BufferedReader](#bufferedreader)
  - [BufferedWriter](#bufferedwriter)
- [Working with Task Groups and Pipes](#working-with-task-groups-and-pipes)
- [Flow Control & Buffering Strategies](#flow-control--buffering-strategies)
- [Types Reference](#types-reference)
- [Best Practices](#best-practices)

## Quick Start

The fastest way to experiment with `@moonbitlang/async/io` is to couple it with an in-memory pipe and an async task group. The writer task produces bytes, while the reader task consumes them:

```moonbit check
///|
async test "quick start pipeline" {
  @async.with_task_group(root => {
    // Create a pair of connected endpoints that speak the Reader/Writer protocols.
    // Data written to the write end (`writer`) can be read from the read end (`reader`)
    let (reader, writer) = @io.pipe()

    // Spawn a background writer that sends a UTF-8 string in three chunks.
    root.spawn_bg(() => {
      defer writer.close()
      writer.write(b"Hello, ")
      @async.sleep(10)
      writer.write(b"MoonBit")
      @async.sleep(10)
      writer.write(b"!\n")
    })

    // Read everything that arrives and print it as text.
    defer reader.close()
    let message = reader.read_all().text()
    inspect(message, content="Hello, MoonBit!\n")
  })
}
```

This pattern generalises to sockets, files, and any type that implements the `Reader` and `Writer` traits. The following sections dive deeper into the building blocks.

## Core Traits

### Data Trait

`Data` is a lightweight trait for types that can be read/write via IO endpoints.
On the sender side, `Data` is implemented by `Bytes`, `BytesView`, `String`, `StringView` and `Json`.
If an API accepts `&Data` as input (for example `Writer::write`), any value of the above types can be passed directly.
On the receiver side, the trait object type `&Data` provides helper methods `.binary()`, `.text()` and `.json()`,
which converts receive data to raw binary/UTF-8 encoded string/UTF-8 encoded JSON string in respect.
This allows convenient conversion of received data to various formats.

```moonbit check
///|
async test "data as binary" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Send raw binary bytes.
      w.write(b"binary data")
    })
    let data = r.read_all()
    let binary = data.binary()
    inspect(@utf8.decode(binary), content="binary data")
  })
}

///|
async test "data as text" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Send UTF-8 encoded string
      w.write("Hello, MoonBit!")
    })
    let data = r.read_all()
    // Decoding happens lazily when `.text()` is invoked.
    inspect(data.text(), content="Hello, MoonBit!")
  })
}

///|
async test "data as json" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // send UTF-8 encoded JSON string
      let data : Json = { "name": "John", "age": 30 }
      w.write(data)
    })
    let data = r.read_all()
    let json = data.json()
    // `json_inspect` asserts that the parsed JSON matches the expected structure.
    json_inspect(json, content={ "name": "John", "age": 30 })
  })
}
```

### Reader Trait

The `Reader` trait exposes three complementary levels of granularity:

- `read` performs a best-effort read into an existing buffer and is ideal for incremental protocols. A zero return value indicates EOF.
- `read_exactly` loops until it fills the requested number of bytes or raises `ReaderClosed`, which is helpful when parsing fixed-width frames.
- `read_some` read the next chunk of data once any new data is available
- `read_all` drains the stream into memory, returning a `&Data` handle for convenient conversion to text, JSON, or binary.
- `read_until` read UTF-8 encoded string from the input until a separator is reached

Each example below shows how a reader pairs with `@io.pipe()` and includes inline comments that highlight the important steps.

```moonbit check
///|
async test "read from reader" {
  @async.with_task_group(root => {
    // Create connected endpoints. `r` is a Reader, `w` is a Writer.
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Emit the payload in a single chunk.
      w.write(b"Hello, World!")
    })
    let buf = FixedArray::make(13, b'0')
    // Read up to 13 bytes into the fixed buffer.
    let n = r.read(buf, offset=0, max_len=13)
    inspect(n, content="13")
    // Convert the binary slice to UTF-8 text for inspection.
    inspect(
      @utf8.decode(buf.unsafe_reinterpret_as_bytes()),
      content="Hello, World!",
    )
  })
}

///|
async test "read_exactly - read exact number of bytes" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Produce a fixed-size frame.
      w.write(b"0123456789")
    })
    // Blocks until exactly 5 bytes are received or ReaderClosed is raised.
    let data1 = r.read_exactly(5)
    inspect(@utf8.decode(data1), content="01234")
    let data2 = r.read_exactly(5)
    inspect(@utf8.decode(data2), content="56789")
  })
}

///|
async test "read_some - read next chunk of data" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // the writer supplieds data in two chunks
      w.write("abcd")
      @async.sleep(200)
      w.write("efgh")
      @async.sleep(200)
      w.write("ijkl")
    })
    inspect(
      r.read_some(),
      content=(
        #|Some(b"abcd")
      ),
    )
    // `read_some` can optionally accept a length limit
    inspect(
      r.read_some(max_len=2),
      content=(
        #|Some(b"ef")
      ),
    )
    // the amount of data returned may be smaller than `max_len`
    inspect(
      r.read_some(max_len=4),
      content=(
        #|Some(b"gh")
      ),
    )
    inspect(
      r.read_some(),
      content=(
        #|Some(b"ijkl")
      ),
    )
    // on EOF, `None` is returned
    inspect(r.read_some(), content="None")
  })
}

///|
async test "read_all - read entire content" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      w.write(b"Complete content")
    })
    // `read_all` accumulates everything into a `&Data` handle.
    let data = r.read_all()
    // Convert to text on demand.
    inspect(data.text(), content="Complete content")
  })
}

///|
async test "read_all large data" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Large payloads can be streamed without precomputing the size.
      w.write(Bytes::make(4097, 0))
    })
    inspect(r.read_all().binary().length(), content="4097")
  })
}

///|
async test "drop - advance stream by discarding data" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      w.write(b"0123456789")
    })
    // Advance the window by five bytes; subsequent reads start after this point.
    // The number of bytes actually dropped would be returned.
    inspect(r.drop(5), content="5")
    let data = r.read_exactly(5)
    inspect(@utf8.decode(data), content="56789")
  })
}

///|
async test "read_until - read text from stream until a separator is found" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      w.write("abcd|")
      w.write("defg")
    })
    // read until the separator "|" is met. The separator will be consumed as well
    inspect(
      r.read_until("|"),
      content=(
        #|Some("abcd")
      ),
    )
    // .. or read until EOF is reached
    inspect(
      r.read_until("|"),
      content=(
        #|Some("defg")
      ),
    )
    // `None` will be returned when no more data is available
    inspect(r.read_until("|"), content="None")
  })
}

///|
#cfg(target="native")
async test "read_until - used to read file line by line" {
  let file = @fs.open("LICENSE", mode=ReadOnly)
  defer file.close()
  let lines = []
  while file.read_until("\n") is Some(line) {
    // Push each decoded line into a growable array.
    lines.push(line)
  }
  inspect(lines.length(), content="202")
  assert_eq(lines.join("\n") + "\n", @fs.read_file("LICENSE").text())
}
```

### Writer Trait

`Writer` focuses on pushing bytes downstream. The three key helpers build on top of the fundamental `write_once` contract:

- `write_once` performs a single best-effort write and returns how many bytes were accepted. Note that partial write is allowed for `write_once`: only a portion of data may be succesfully written. End users should not call `write_once` directly in general.
- `write` encodes and writes a `&Data` to the writer, is will keep calling `write_once` until all data are succesfully written. This is the most common helper users should use.
- `write_reader` streams from any `Reader`, making it perfect for relaying pipes, sockets, or files without copying into intermediate strings.

The snippets below demonstrate each mode with progressive complexity.

```moonbit check
///|
async test "write to writer" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Each call appends to the outgoing stream.
      w.write(b"Hello")
      w.write(b", ")
      w.write(b"World!")
    })
    // `read_all` collapses everything for verification.
    let data = r.read_all()
    inspect(data.text(), content="Hello, World!")
  })
}

///|
async test "write_once - single write operation" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      let data : Bytes = b"Test data"
      // Manually call `write_once` to demonstrate partial write accounting.
      let written = w.write_once(data, offset=0, len=data.length())
      inspect(written, content="9")
    })
    let content = r.read_all()
    inspect(content.text(), content="Test data")
  })
}

///|
async test "write large data" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      let data = Bytes::make(1024 * 16, 0)
      // `write` handles chunking internally, avoiding manual loops.
      w.write(data)
    })
    root.spawn_bg(() => {
      defer r.close()
      inspect(r.read_all().binary().length(), content="16384")
    })
  })
}

///|
async test "write_reader - copy from reader to writer" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r1, w1) = @io.pipe()
    let (r2, w2) = @io.pipe()
    root.spawn_bg(() => {
      defer r2.close()
      defer w1.close()
      // Stream everything from `r2` into `w1` via `write_reader`.
      w1.write_reader(r2)
    })
    root.spawn_bg(() => {
      defer r1.close()
      while r1.read_some() is Some(data) {
        let data = @utf8.decode(data)
        log.write_string("received \{data}\n")
      }
    })
    root.spawn_bg(() => {
      defer w2.close()
      // Simulate a producer that emits three frames with pauses in between.
      log.write_string("sending 4 bytes\n")
      w2.write(b"abcd")
      @async.sleep(300)
      log.write_string("sending 4 bytes\n")
      w2.write(b"efgh")
      @async.sleep(300)
      log.write_string("sending 4 bytes\n")
      w2.write(b"ijkl")
    })
  })
  inspect(
    log.to_string(),
    content=(
      #|sending 4 bytes
      #|received abcd
      #|sending 4 bytes
      #|received efgh
      #|sending 4 bytes
      #|received ijkl
      #|
    ),
  )
}

///|
async test "write string" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      // Unicode data is transparently encoded via UTF-8.
      w.write("abcd中文☺")
    })
    inspect(r.read_all().text(), content="abcd中文☺")
  })
}
```

## Buffered I/O

### BufferedWriter

`BufferedWriter` batches small writes into a fixed-capacity buffer before flushing them to the underlying destination. This greatly reduces syscall overhead and network chatter when dealing with chatty protocols. You can control the buffer size at construction time and decide when to `flush` explicitly—for example before handing the underlying writer to a different subsystem.

```moonbit check
///|
async test "BufferedWriter - basic buffering" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      let w = @io.BufferedWriter::new(w, size=4)
      log.write_string("2 bytes written\n")
      w.write("ab")
      @async.sleep(20)
      log.write_string("2 bytes written\n")
      w.write("cd")
      @async.sleep(20)
      log.write_string("2 bytes written\n")
      w.write("ef")
      // Force the remaining bytes out of the buffer.
      w.flush()
    })
    root.spawn_bg(() => {
      defer r.close()
      while r.read_some() is Some(data) {
        log.write_string("received: \{@utf8.decode(data)}\n")
      }
    })
  })
  inspect(
    log.to_string(),
    content=(
      #|2 bytes written
      #|2 bytes written
      #|2 bytes written
      #|received: abcd
      #|received: ef
      #|
    ),
  )
}

///|
async test "BufferedWriter::new with custom size" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      let w = @io.BufferedWriter::new(w, size=8)
      inspect(w.capacity(), content="8")
      // Writes remain buffered until an explicit flush.
      w.write(b"test")
      w.flush()
    })
    let data = r.read_all()
    inspect(data.text(), content="test")
  })
}

///|
async test "BufferedWriter::flush - commit buffered data" {
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    defer r.close()
    root.spawn_bg(() => {
      defer w.close()
      let w = @io.BufferedWriter::new(w, size=16)
      w.write(b"buffer")
      w.flush()
      // Data written after the flush remains buffered until the next flush.
      w.write(b"more")
      w.flush()
    })
    let data = r.read_all()
    inspect(data.text(), content="buffermore")
  })
}

///|
async test "BufferedWriter::write_reader - buffered copy" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r1, w1) = @io.pipe()
    let (r2, w2) = @io.pipe()
    root.spawn_bg(() => {
      defer r2.close()
      defer w1.close()
      let w1 = @io.BufferedWriter::new(w1, size=6)
      w1.write_reader(r2)
      // Flush ensures the trailing fragment is committed before closing.
      w1.flush()
    })
    root.spawn_bg(() => {
      defer r1.close()
      while r1.read_some() is Some(data) {
        let data = @utf8.decode(data)
        log.write_string("received \{data}\n")
      }
    })
    root.spawn_bg(() => {
      defer w2.close()
      log.write_string("sending 4 bytes\n")
      w2.write(b"abcd")
      @async.sleep(100)
      log.write_string("sending 4 bytes\n")
      w2.write(b"efgh")
      @async.sleep(100)
      log.write_string("sending 4 bytes\n")
      w2.write(b"ijkl")
    })
  })
  inspect(
    log.to_string(),
    content=(
      #|sending 4 bytes
      #|sending 4 bytes
      #|received abcdef
      #|sending 4 bytes
      #|received ghijkl
      #|
    ),
  )
}
```

## Flow Control & Buffering Strategies

Efficient asynchronous I/O is mostly about balancing throughput and memory usage. Some guiding principles:

- **Prefer streaming copies for large payloads.** `Writer::write_reader` efficiently bridges readers and writers without allocating entire buffers up front.
- **Tune buffer sizes per transport.** A 4 KB buffer is often enough for network sockets, whereas disk-backed streams may benefit from larger chunks. Use `BufferedWriter::new(size=...)` and `BufferedReader::SEGMENT_SIZE` multiples strategically.
- **Avoid a lot of small drops.** `BufferedReader::drop` and `BufferedReader::read` are expensive operations, as they need to copy data when advancing the reader stream. It is recommended to use `op_as_view` to extract data and batch small `read` operations into a single `drop` call at the end when reading multiple small data fragments. `drop` should still be called from time to time, though, to reduce the memory consumption of `BufferedReader`.
- **Flush deliberately.** Frequent flushes lower latency but reduce batching efficiency; schedule them at protocol boundaries (e.g., end of a response frame).

## Types Reference

### Reader

Trait for reading data from a source. Methods include:
- `read(buffer, offset?, max_len?)` - Read data into buffer
- `read_exactly(len)` - Read exact number of bytes
- `read_all()` - Read entire content

### Writer

Trait for writing data to a destination. Methods include:
- `write_once(data, offset~, len~)` - Single write operation
- `write(data)` - Write data (may require multiple operations)
- `write_reader(reader)` - Copy data from reader to writer

### Data

Trait for abstracting various data formats. Implementations:
- `Bytes` - Raw binary data
- `BytesView` - View of binary data
- `String` - UTF-8 encoded string
- `StringView` - View of string
- `Json` - JSON data

Helper methods for received data:
- `binary()` - Extract raw binary data
- `text()` - Decode as UTF-8 string
- `json()` - Decode as JSON

### BufferedReader

A buffered reader that wraps around a normal reader. Methods include:
- `new(reader)` - Create new buffered reader
- `read(buffer, offset?, max_len?)` - Read data
- `read_exactly(len)` - Read exact number of bytes
- `read_all()` - Read entire content
- `op_get(index)` - Access byte by index
- `op_as_view(start?, end~)` - Get slice as view
- `drop(n)` - Drop first n bytes
- `find(target)` - Find substring (raises error if not found)
- `find_opt(target)` - Find substring (returns None if not found)
- `read_line()` - Read line until newline

### BufferedWriter

A buffered writer with fixed-size buffer. Methods include:
- `new(writer, size?)` - Create new buffered writer
- `capacity()` - Get buffer size
- `flush()` - Commit buffered data
- `write_once(data, offset~, len~)` - Single write operation
- `write(data)` - Write data
- `write_reader(reader)` - Copy from reader

### Encoding

Encoding format for text operations:
- `UTF8` - UTF-8 encoding

### ReaderClosed

Error raised when attempting to read from a closed reader.

## Best Practices

1. **Only one reader/writer at the same time**. Attempting to read from/write to the same reader/writer from multiple tasks easily lead to race condition.
  When multiple readers/writers are needed, it is recommended to adapt the actor pattern by spawning a dedicated reader/writer task and use `@aqueue.Queue` to distribute data atomically.
2. **Use buffered I/O for performance**: Wrap readers and writers with `BufferedReader` and `BufferedWriter` when performing many small reads or writes.
3. **Pick the right data view and cache the result**: Prefer `.text()` for UTF-8, `.json()` for structured payloads, and `.binary()` when forwarding raw bytes.
  `.text()` and `.json()` methods need to perform decoding and parsing, so users should cache the result of these conversion methods instead of calling them repeatedly

For more examples and detailed usage, explore the test suites in this package—they double as executable documentation.

