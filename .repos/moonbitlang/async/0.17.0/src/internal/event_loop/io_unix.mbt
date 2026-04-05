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
#cfg(not(platform="windows"))
struct IoHandle {
  mut fd : @fd_util.Fd
  kind : @fd_util.FileKind
  is_async : Bool
  mut events : Int
  mut read : @coroutine.Coroutine?
  mut write : @coroutine.Coroutine?
}

///|
#cfg(not(platform="windows"))
pub fn IoHandle::from_fd(
  fd : @fd_util.Fd,
  kind~ : @fd_util.FileKind,
  is_async? : Bool = true,
) -> IoHandle raise {
  guard curr_loop.val is Some(evloop)
  guard evloop.fds.get(fd) is None
  if is_async {
    @fd_util.set_nonblocking(fd, context="@event_loop.IoHandle::from_fd()")
  }
  let handle = { fd, kind, is_async, read: None, write: None, events: NoEvent }
  evloop.fds[fd] = handle
  handle
}

///|
#cfg(not(platform="windows"))
fn IoHandle::prepare_read(handle : IoHandle) -> Unit raise {
  guard curr_loop.val is Some(evloop)
  guard @fd_util.fd_is_valid(handle.fd) else {
    abort("file descriptor already closed")
  }
  if (handle.events & ReadEvent) == 0 {
    evloop.poll.register(
      handle.fd,
      prev_events=handle.events,
      new_events=ReadEvent,
      oneshot=false,
    )
    handle.events = handle.events | ReadEvent
  }
}

///|
#cfg(not(platform="windows"))
async fn IoHandle::wait_read(handle : IoHandle) -> Unit {
  guard (handle.events & ReadEvent) != 0
  guard @fd_util.fd_is_valid(handle.fd) else {
    abort("file descriptor already closed")
  }
  guard handle.read is None
  handle.read = Some(@coroutine.current_coroutine())
  defer {
    handle.read = None
  }
  @coroutine.suspend()
}

///|
#cfg(not(platform="windows"))
fn IoHandle::prepare_write(handle : IoHandle) -> Unit raise {
  guard curr_loop.val is Some(evloop)
  guard @fd_util.fd_is_valid(handle.fd) else {
    abort("file descriptor already closed")
  }
  if (handle.events & WriteEvent) == 0 {
    evloop.poll.register(
      handle.fd,
      prev_events=handle.events,
      new_events=WriteEvent,
      oneshot=false,
    )
    handle.events = handle.events | WriteEvent
  }
}

///|
#cfg(not(platform="windows"))
async fn IoHandle::wait_write(handle : IoHandle) -> Unit {
  guard (handle.events & WriteEvent) != 0
  guard @fd_util.fd_is_valid(handle.fd) else {
    abort("file descriptor already closed")
  }
  guard handle.write is None
  let coro = @coroutine.current_coroutine()
  handle.write = Some(coro)
  defer {
    handle.write = None
  }
  @coroutine.suspend()
}

///|
/// Detach a file descriptor from the event loop,
/// but does not close the file descriptor itself.
/// The underlying file descriptor is returned.
#cfg(not(platform="windows"))
pub fn IoHandle::detach_from_event_loop(handle : IoHandle) -> @fd_util.Fd {
  guard curr_loop.val is Some(evloop)
  guard @fd_util.fd_is_valid(handle.fd) else { @fd_util.invalid_fd }
  evloop.fds.remove(handle.fd)
  if !(handle.events is NoEvent) {
    evloop.poll.remove(handle.fd, events=handle.events) catch {
      err => abort("detach \{handle.fd} from loop: \{err}")
    }
  }
  let fd = handle.fd
  handle.fd = @fd_util.invalid_fd
  fd
}

///|
#cfg(not(platform="windows"))
#borrow(buf)
extern "C" fn read_ffi(
  fd : @fd_util.Fd,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
) -> Int = "moonbitlang_async_read"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::read(
  handle : IoHandle,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
  context~ : String,
) -> Int {
  if handle.is_async {
    @coroutine.check_cancellation()
    handle.prepare_read()
    let ret = read_ffi(handle.fd, buf, offset~, len~)
    if ret >= 0 {
      @coroutine.pause()
      return ret
    }
    let ret = if @os_error.is_nonblocking_io_error() {
      handle.wait_read()
      read_ffi(handle.fd, buf, offset~, len~)
    } else {
      ret
    }
    if ret < 0 {
      @os_error.check_errno(context)
    }
    ret
  } else {
    let cancel = if handle.kind.can_poll() {
      guard curr_loop.val is Some(evloop)
      Some(job_id => evloop.cancel_job_in_worker(job_id, context~))
    } else {
      None
    }
    let job = Job::read(handle.fd, buf, offset, len, position=-1)
    perform_job_in_worker(job, context~, cancel?)
  }
}

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::read_at(
  handle : IoHandle,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
  position~ : Int64,
  context~ : String,
) -> Int {
  guard !handle.kind.can_poll()
  let job = Job::read(handle.fd, buf, offset, len, position~)
  perform_job_in_worker(job, context~)
}

///|
#cfg(not(platform="windows"))
#borrow(buf)
extern "C" fn write_ffi(
  fd : @fd_util.Fd,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
) -> Int = "moonbitlang_async_write"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::write(
  handle : IoHandle,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
  context~ : String,
) -> Int {
  if handle.is_async {
    @coroutine.check_cancellation()
    handle.prepare_write()
    let ret = write_ffi(handle.fd, buf, offset~, len~)
    if ret >= 0 {
      @coroutine.pause()
      return ret
    }
    let ret = if @os_error.is_nonblocking_io_error() {
      handle.wait_write()
      write_ffi(handle.fd, buf, offset~, len~)
    } else {
      ret
    }
    if ret < 0 {
      @os_error.check_errno(context)
    }
    ret
  } else {
    let cancel = if handle.kind.can_poll() {
      guard curr_loop.val is Some(evloop)
      Some(job_id => evloop.cancel_job_in_worker(job_id, context~))
    } else {
      None
    }
    let job = Job::write(handle.fd, buf, offset, len, position=-1)
    perform_job_in_worker(job, context~, cancel?)
  }
}

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::write_at(
  handle : IoHandle,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
  position~ : Int64,
  context~ : String,
) -> Unit {
  guard !handle.kind.can_poll()
  let job = Job::write(handle.fd, buf, offset, len, position~)
  perform_job_in_worker(job, context~) |> ignore
}
