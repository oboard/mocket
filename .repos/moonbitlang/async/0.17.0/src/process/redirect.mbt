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
/// A temporary pipe used to read output from a spawned process
struct ReadFromProcess {
  io : @event_loop.IoHandle
  read_buf : @io.ReaderBuffer
}

///|
/// A temporary pipe used to write data to a spawned process
struct WriteToProcess(@event_loop.IoHandle)

///|
/// Create a temporary pipe for reading from stdout/stderr of a process.
/// The return value is a pair `(r, w)`,
/// where `r` is a temporary pipe that can be used to read process output,
/// and `w` should be passed to `@process.run`.
///
/// `w` is temporary: it can only be passed to one `@process.run` call.
/// However, it is safe to pass `w` to both `stdout` and `stderr` of the same process.
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  let context = "@process.read_from_process()"
  let (r, w) = @fd_util.pipe(
    read_end_is_async=true,
    write_end_is_async=false,
    context~,
  )
  try {
    let io = @event_loop.IoHandle::from_fd(r, kind=Pipe)
    (
      { io, read_buf: @io.ReaderBuffer::new() },
      TempPipeWrite::{ pipe: w, closed: false },
    )
  } catch {
    err => {
      @fd_util.close(r, kind=Pipe, context~)
      @fd_util.close(w, kind=Pipe, context~)
      raise err
    }
  }
}

///|
/// Create a temporary pipe for writing to stdin of a process.
/// The return value is a pair `(r, w)`,
/// where `w` is a temporary pipe that can be used to write to process output,
/// and `r` should be passed to `@process.run`.
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  let context = "@process.read_from_process()"
  let (r, w) = @fd_util.pipe(
    read_end_is_async=false,
    write_end_is_async=true,
    context~,
  )
  try {
    let io = @event_loop.IoHandle::from_fd(w, kind=Pipe)
    (TempPipeRead::{ pipe: r, closed: false }, io)
  } catch {
    err => {
      @fd_util.close(r, kind=Pipe, context~)
      @fd_util.close(w, kind=Pipe, context~)
      raise err
    }
  }
}

///|
pub fn ReadFromProcess::close(self : ReadFromProcess) -> Unit {
  self.io.close()
}

///|
pub impl @io.Reader for ReadFromProcess with _get_internal_buffer(self) {
  self.read_buf
}

///|
pub impl @io.Reader for ReadFromProcess with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.io.read(
    buf,
    offset~,
    len=max_len,
    context="@process.ReadFromProcess::read()",
  )
}

///|
pub fn WriteToProcess::close(self : WriteToProcess) -> Unit {
  let WriteToProcess(io) = self
  io.close()
}

///|
pub impl @io.Writer for WriteToProcess with write_once(self, buf, offset~, len~) {
  let WriteToProcess(io) = self
  io.write(buf, offset~, len~, context="@process.WriteToProcess::write()")
}

///|
/// Redirect the output of a process to the file at `path`.
/// The meaning of `append`, `create` and `truncate` is the same as `@fs.open`,
/// see the document of `@fs.open` for more details.
pub async fn redirect_to_file(
  path : String,
  append? : Bool = false,
  create? : Int,
  truncate? : Bool = false,
) -> &ProcessOutput {
  let (create, mode) = match create {
    Some(mode) => (true, mode)
    None => (false, 0)
  }
  let (fd, kind) = @event_loop.open_detached(
    path,
    1, // write only
    create~,
    append~,
    truncate~,
    sync=0,
    mode~,
    context="@process.redirect_to_file()",
  )
  RedirectToFile(fd, @fd_util.FileKind::from_sys_kind(kind))
}

///|
/// Redirect the content of a file at `path` to the stdin of a process.
pub async fn redirect_from_file(path : String) -> &ProcessInput {
  let (fd, kind) = @event_loop.open_detached(
    path,
    0, // read only
    create=false,
    append=false,
    truncate=false,
    sync=0,
    mode=0,
    context="@process.redirect_to_file()",
  )
  RedirectToFile(fd, @fd_util.FileKind::from_sys_kind(kind))
}

///|
/// An entity that can be used to redirect stdin of a process
trait ProcessInput {
  fd(Self) -> @fd_util.Fd
  after_spawn(Self) -> Unit = _
}

///|
impl ProcessInput with after_spawn(_) {
  ()
}

///|
pub impl ProcessInput for @pipe.PipeRead with fd(self) {
  self.fd()
}

///|
pub impl ProcessInput for @stdio.Input with fd(self) {
  self.fd()
}

///|
/// An entity that can be used to redirect stdout/stderr of a process
trait ProcessOutput {
  fd(Self) -> @fd_util.Fd
  after_spawn(Self) -> Unit = _
}

///|
impl ProcessOutput with after_spawn(_) {
  ()
}

///|
pub impl ProcessOutput for @pipe.PipeWrite with fd(self) {
  self.fd()
}

///|
pub impl ProcessOutput for @stdio.Output with fd(self) {
  self.fd()
}

///|
priv struct TempPipeRead {
  pipe : @fd_util.Fd
  mut closed : Bool
}

///|
priv struct TempPipeWrite {
  pipe : @fd_util.Fd
  mut closed : Bool
}

///|
impl ProcessOutput for TempPipeWrite with fd(self) {
  self.pipe
}

///|
impl ProcessOutput for TempPipeWrite with after_spawn(self) {
  if !self.closed {
    self.closed = true
    @fd_util.close(self.pipe, kind=Pipe, context="") catch {
      _ => ()
    }
  }
}

///|
impl ProcessInput for TempPipeRead with fd(self) {
  self.pipe
}

///|
impl ProcessInput for TempPipeRead with after_spawn(self) {
  if !self.closed {
    self.closed = true
    @fd_util.close(self.pipe, kind=Pipe, context="") catch {
      _ => ()
    }
  }
}

///|
priv struct RedirectToFile(@fd_util.Fd, @fd_util.FileKind)

///|
impl ProcessOutput for RedirectToFile with fd(self) {
  self.0
}

///|
impl ProcessOutput for RedirectToFile with after_spawn(self) {
  @fd_util.close(self.0, kind=self.1, context="") catch {
    _ => ()
  }
}

///|
impl ProcessInput for RedirectToFile with fd(self) {
  self.0
}

///|
impl ProcessInput for RedirectToFile with after_spawn(self) {
  @fd_util.close(self.0, kind=self.1, context="") catch {
    _ => ()
  }
}
