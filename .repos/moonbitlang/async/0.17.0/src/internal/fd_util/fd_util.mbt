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
#cfg(platform="windows")
#external
pub type Fd

///|
#cfg(platform="windows")
pub impl Eq for Fd with equal(x, y) = "%refeq"

///|
#cfg(platform="windows")
extern "C" fn Fd::to_uint64(fd : Fd) -> UInt64 = "moonbitlang_async_fd_as_uint64"

///|
#cfg(platform="windows")
pub impl Hash for Fd with hash_combine(self, hasher) {
  hasher.combine_uint64(self.to_uint64())
}

///|
#cfg(not(platform="windows"))
pub type Fd = Int

///|
#cfg(not(platform="windows"))
extern "C" fn fd_is_nonblocking_ffi(fd : Fd) -> Int = "moonbitlang_async_fd_is_nonblocking"

///|
#cfg(not(platform="windows"))
pub fn fd_is_nonblocking(fd : Fd, context~ : String) -> Bool raise {
  let ret = fd_is_nonblocking_ffi(fd)
  if ret < 0 {
    @os_error.check_errno(context)
  }
  ret > 0
}

///|
#cfg(not(platform="windows"))
extern "C" fn set_blocking_ffi(fd : Fd) -> Int = "moonbitlang_async_set_blocking"

///|
#cfg(not(platform="windows"))
pub fn set_blocking(fd : Fd, context~ : String) -> Unit raise {
  if set_blocking_ffi(fd) < 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(not(platform="windows"))
extern "C" fn set_nonblocking_ffi(fd : Fd) -> Int = "moonbitlang_async_set_nonblocking"

///|
#cfg(not(platform="windows"))
pub fn set_nonblocking(fd : Fd, context~ : String) -> Unit raise {
  if set_nonblocking_ffi(fd) < 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(not(platform="windows"))
extern "C" fn set_cloexec_ffi(fd : Fd) -> Int = "moonbitlang_async_set_cloexec"

///|
#cfg(not(platform="windows"))
pub fn set_cloexec(fd : Fd, context~ : String) -> Unit raise {
  if set_cloexec_ffi(fd) < 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(not(platform="windows"))
extern "C" fn close_ffi(fd : Fd) -> Int = "close"

///|
#cfg(not(platform="windows"))
pub fn close(fd : Fd, kind~ : FileKind, context~ : String) -> Unit raise {
  ignore(kind)
  if close_ffi(fd) < 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(platform="windows")
extern "C" fn close_ffi(fd : Fd, is_socket~ : Bool) -> Int = "moonbitlang_async_close_fd"

///|
#cfg(platform="windows")
pub fn close(fd : Fd, kind~ : FileKind, context~ : String) -> Unit raise {
  if close_ffi(fd, is_socket=kind is Socket) == 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(platform="windows")
extern "C" fn get_invalid_handle() -> Fd = "moonbitlang_async_get_invalid_handle"

///|
#cfg(platform="windows")
pub let invalid_fd : Fd = get_invalid_handle()

///|
#cfg(platform="windows")
pub fn fd_is_valid(fd : Fd) -> Bool {
  fd != invalid_fd
}

///|
#cfg(not(platform="windows"))
pub let invalid_fd : Fd = -1

///|
#cfg(not(platform="windows"))
pub fn fd_is_valid(fd : Fd) -> Bool {
  fd >= 0
}
