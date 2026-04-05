// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
#external
priv type StreamReader

///|
priv struct ReadableStreamChunk {
  value : Bytes
  done : Bool
}

///|
extern "js" fn StreamReader::read_ffi(
  reader : Self,
) -> Promise[ReadableStreamChunk] =
  #| (reader) => reader.read()

///|
async fn StreamReader::read(reader : StreamReader) -> Bytes? {
  match reader.read_ffi().wait() {
    { done: true, .. } => None
    { done: false, value } => Some(value)
  }
}

///|
extern "js" fn StreamReader::release_lock(reader : Self) -> Unit =
  #| (stream) => stream.releaseLock()

///|
#external
priv type ReadableStreamController

///|
extern "js" fn ReadableStreamController::close(controller : Self) =
  #| (controller) => controller.close()

///|
extern "js" fn ReadableStreamController::enqueue(
  controller : Self,
  chunk : Bytes,
) =
  #| (controller, chunk) => controller.enqueue(chunk)

///|
/// The `ReadableStream` type in Web API, see
///   https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
/// for more details.
///
/// Use this type on JavaScript FFI boundary to interact with
/// API that make use of `ReadableStream`, such as `fetch`.
#external
type JsReadableStream

///|
extern "js" fn JsReadableStream::new(
  pull : (ReadableStreamController) -> Promise[Unit],
  cancel : (JsValue) -> Unit,
) -> JsReadableStream =
  #| (f, cancel) => new ReadableStream({ start: f, pull: f, cancel: cancel })

///|
extern "js" fn JsReadableStream::cancel(stream : Self) -> Unit =
  #| (stream) => stream.cancel()

///|
extern "js" fn JsReadableStream::get_reader(stream : Self) -> StreamReader =
  #| (stream) => stream.getReader()

///|
/// A wrapper around `JsReadableStream`
/// that allows reading the content of the stream via the `@io.Reader` interface.
///
/// This type SHOULD NOT be used on FFI directly:
/// its ABI is NOT the same as `JsReadableStream`,
/// and most JavaScript types won't understand it.
struct ReadableStream {
  read_end : @io.PipeRead
  worker : @coroutine.Coroutine
}

///|
/// Create a `ReadableStream` wrapper from a `JsReadableStream` object,
/// in order to read the content of the stream from the MoonBit side.
/// The ownership of the JS stream will be transferred to the `ReadableStream`:
/// other code cannot read the stream anymore.
pub fn ReadableStream::from_js(stream : JsReadableStream) -> ReadableStream {
  let (r, w) = @io.pipe()
  // Here, we use a coroutine to copy the data,
  // because the `.read()` method of `StreamReader` is NOT cancellable.
  // It can only be cancelled by cancelling the whole stream.
  // So we use a `@io.pipe` in the middle to provide proper cancellation support.
  let worker = @coroutine.spawn(() => {
    defer w.close()
    defer stream.cancel()
    let reader = stream.get_reader()
    defer reader.release_lock()
    while reader.read() is Some(chunk) {
      w.write(chunk)
    }
  })
  { read_end: r, worker }
}

///|
/// Close a `ReadableStream`. The underlying JS stream will be cancelled.
pub fn ReadableStream::close(self : ReadableStream) -> Unit {
  self.worker.cancel()
  self.read_end.close()
}

///|
pub impl @io.Reader for ReadableStream with _get_internal_buffer(self) {
  self.read_end._get_internal_buffer()
}

///|
pub impl @io.Reader for ReadableStream with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.read_end._direct_read(buf, offset~, max_len~)
}

///|
/// Create an anonymous pipe and wrap the read end into a `JsReadableStream`.
/// This allows writing data from MoonBit code to JavaScript.
/// Usually users should pass the read end of the pipe (`JsReadableStream`)
/// to JavaScript code, and write to the write end of the pipe (`@io.PipeWrite`)
/// from MoonBit code.
///
/// Closing the write end of the pipe will signal EOF on the read end.
/// If the read end of the stream is cancelled from the JavaScript side,
/// further write operations on the write end will fail with error.
pub fn JsReadableStream::new_pipe() -> (JsReadableStream, @io.PipeWrite) {
  let abort_controller = AbortController::new()
  let abort_signal = abort_controller.signal()
  let (pipe_r, pipe_w) = @io.pipe()
  fn pull(controller : ReadableStreamController) {
    Promise::from_async(abort_signal~, () => {
      guard pipe_r.read_some(max_len=1024) is Some(chunk) else {
        controller.close()
      }
      controller.enqueue(chunk)
    })
  }
  fn cancel(_reason) {
    pipe_r.close()
    abort_controller.abort()
    @coroutine.reschedule()
  }
  let stream = JsReadableStream::new(pull, cancel)
  (stream, pipe_w)
}
