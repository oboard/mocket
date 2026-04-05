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
fn setup_stdio(fd : Int, context~ : String) -> IoHandle {
  let kind = @fd_util.get_fd_kind_sync(fd, context~) catch {
    err => abort("\{context}: \{err}")
  }
  let is_async = try! @fd_util.fd_is_nonblocking(fd, context~)
  let handle = { fd, kind, is_async, events: NoEvent, read: None, write: None }
  register_hook(
    init=() => {
      guard curr_loop.val is Some(evloop)
      guard evloop.fds.get(fd) is None
      evloop.fds[fd] = handle
    },
    exit=() => {
      let _ = handle.detach_from_event_loop()
      handle.events = NoEvent
    },
  )
  handle
}

///|
#cfg(platform="windows")
extern "C" fn get_std_handle(id : Int) -> @fd_util.Fd = "moonbitlang_async_get_std_handle"

///|
#cfg(platform="windows")
fn setup_stdio(id : Int, context~ : String) -> IoHandle {
  // The value comes from https://learn.microsoft.com/en-us/windows/console/getstdhandle
  let fd = get_std_handle(-10 - id)
  if !@fd_util.fd_is_valid(fd) {
    let errno = @os_error.get_errno()
    abort("\{context}: \{@os_error.errno_to_string(errno)}")
  }
  let kind = @fd_util.get_fd_kind_sync(fd, context~) catch {
    @os_error.OSError(errno, context~) =>
      abort("\{context}: \{@os_error.errno_to_string(errno)}")
    err => abort("\{context}: \{err}")
  }
  let handle = {
    fd,
    kind,
    is_async: false,
    reading: false,
    read_offset: 0,
    writing: false,
    write_offset: 0,
  }

  // register stdio on event loop creation.
  // This allows multiple event loop inside a single program.
  register_hook(
    init=() => {
      guard curr_loop.val is Some(evloop)
      guard evloop.fds.get(fd) is None
      evloop.fds[fd] = handle
    },
    exit=() => ignore(handle.detach_from_event_loop()),
  )
  handle
}

///|
pub let stdin : IoHandle = setup_stdio(0, context="initialize `stdin`")

///|
pub let stdout : IoHandle = setup_stdio(1, context="initialize `stdout`")

///|
pub let stderr : IoHandle = setup_stdio(2, context="initialize `stderr`")
