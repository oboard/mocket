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
#borrow(out)
extern "C" fn get_fd_kind_sync_ffi(fd : Fd, out : Ref[Int64]) -> Int = "moonbitlang_async_get_fd_kind_sync"

///|
pub fn get_fd_kind_sync(fd : Fd, context~ : String) -> FileKind raise {
  let out = Ref::new(0L)
  if get_fd_kind_sync_ffi(fd, out) < 0 {
    @os_error.check_errno(context)
  }
  FileKind::from_sys_kind(out.val)
}

///|
pub(all) enum FileKind {
  Unknown = 0
  Regular = 1
  Directory = 2
  SymLink = 3
  Socket = 4
  Pipe = 5
  BlockDevice = 6
  CharDevice = 7
} derive(Eq, Show)

///|
pub fn FileKind::can_poll(self : FileKind) -> Bool {
  match self {
    Socket | Pipe | CharDevice => true
    Unknown | Regular | Directory | SymLink | BlockDevice => false
  }
}

///|
pub extern "C" fn FileKind::from_sys_kind(sys_kind : Int64) -> FileKind = "moonbitlang_async_file_kind_from_sys_kind"

///|
struct FileTime(FixedArray[Byte])

///|
extern "C" fn FileTime::size() -> Int = "moonbitlang_async_sizeof_file_time"

///|
pub fn FileTime::new() -> FileTime {
  FixedArray::make(FileTime::size(), b'\x00')
}

///|
#borrow(self)
extern "C" fn FileTime::atime_sec_ffi(self : FileTime) -> Int64 = "moonbitlang_async_get_atime_sec"

///|
#borrow(self)
extern "C" fn FileTime::atime_nsec_ffi(self : FileTime) -> Int = "moonbitlang_async_get_atime_nsec"

///|
pub fn FileTime::atime(self : FileTime) -> (Int64, Int) {
  (self.atime_sec_ffi(), self.atime_nsec_ffi())
}

///|
#borrow(self)
extern "C" fn FileTime::mtime_sec_ffi(self : FileTime) -> Int64 = "moonbitlang_async_get_mtime_sec"

///|
#borrow(self)
extern "C" fn FileTime::mtime_nsec_ffi(self : FileTime) -> Int = "moonbitlang_async_get_mtime_nsec"

///|
pub fn FileTime::mtime(self : FileTime) -> (Int64, Int) {
  (self.mtime_sec_ffi(), self.mtime_nsec_ffi())
}

///|
#borrow(self)
extern "C" fn FileTime::ctime_sec_ffi(self : FileTime) -> Int64 = "moonbitlang_async_get_ctime_sec"

///|
#borrow(self)
extern "C" fn FileTime::ctime_nsec_ffi(self : FileTime) -> Int = "moonbitlang_async_get_ctime_nsec"

///|
pub fn FileTime::ctime(self : FileTime) -> (Int64, Int) {
  (self.ctime_sec_ffi(), self.ctime_nsec_ffi())
}
