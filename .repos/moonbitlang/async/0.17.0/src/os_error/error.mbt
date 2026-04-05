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
pub extern "C" fn get_errno() -> Int = "moonbitlang_async_get_errno"

///|
extern "C" fn errno_is_nonblocking_io_error(errno : Int) -> Bool = "moonbitlang_async_is_nonblocking_io_error"

///|
extern "C" fn errno_is_EINTR(errno : Int) -> Bool = "moonbitlang_async_is_EINTR"

///|
extern "C" fn errno_is_ENOENT(errno : Int) -> Bool = "moonbitlang_async_is_ENOENT"

///|
extern "C" fn errno_is_EEXIST(errno : Int) -> Bool = "moonbitlang_async_is_EEXIST"

///|
extern "C" fn errno_is_EACCES(errno : Int) -> Bool = "moonbitlang_async_is_EACCES"

///|
extern "C" fn errno_is_ECONNREFUSED(errno : Int) -> Bool = "moonbitlang_async_is_ECONNREFUSED"

///|
pub fn is_nonblocking_io_error() -> Bool {
  errno_is_nonblocking_io_error(get_errno())
}

///|
extern "C" fn strerror(errno : Int) -> @c_buffer.Buffer = "moonbitlang_async_errno_to_string"

///|
extern "C" fn free_errno_str(str : @c_buffer.Buffer) = "moonbitlang_async_free_errno_str"

///|
#internal(internal, "for internal use only")
pub fn errno_to_string(errno : Int) -> String {
  let c_str = strerror(errno)
  defer free_errno_str(c_str)
  @os_string.decode(c_str).trim_end(chars="\r\n").to_string()
}

///|
pub(all) suberror OSError {
  OSError(Int, context~ : String)
} derive(ToJson)

///|
pub impl Show for OSError with output(self, logger) -> Unit {
  let OSError(errno, context~) = self
  logger
  ..write_string("OSError(")
  ..write_object("\{context}: \{errno_to_string(errno)}")
  .write_string(")")
}

///|
pub fn OSError::is_nonblocking_io_error(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_nonblocking_io_error(errno)
}

///|
pub fn OSError::is_EINTR(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_EINTR(errno)
}

///|
/// Detect whether the error is the `ENOENT` (no such file or directory) error.
pub fn OSError::is_ENOENT(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_ENOENT(errno)
}

///|
/// Detect whether the error is the `EEXIST` (already exists) error.
pub fn OSError::is_EEXIST(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_EEXIST(errno)
}

///|
/// Detect whether the error is the `EACCES` (permission denied) error.
pub fn OSError::is_EACCES(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_EACCES(errno)
}

///|
/// Detect whether the error is the `ECONNREFUSED` (connection refused) error.
pub fn OSError::is_ECONNREFUSED(err : OSError) -> Bool {
  let OSError(errno, ..) = err
  errno_is_ECONNREFUSED(errno)
}

///|
pub fn check_errno(context : String) -> Unit raise OSError {
  let err_code = get_errno()
  if err_code != 0 {
    raise OSError(err_code, context~)
  }
}
