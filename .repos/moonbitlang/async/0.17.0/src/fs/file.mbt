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
struct File {
  io : @event_loop.IoHandle
  read_buf : @io.ReaderBuffer
}

///|
pub fn File::fd(self : File) -> @fd_util.Fd {
  self.io.fd()
}

///|
pub fn File::close(self : File) -> Unit {
  self.io.close()
}

///|
pub(all) enum Mode {
  ReadOnly = 0
  WriteOnly
  ReadWrite
}

///|
/// Determine how data is synchronized after writing:
///
/// - `NoSync` means no synchronization is performed.
///
/// - `Data` means the data part and relevant metadata such as file size
///   will be synchronized immediately after a `write` call,
///   but other metadata, such as last access time, will not.
///   See man page of `fdatasync(2)` for more details.
///
/// - `Full` means all data and metdata will be synchronized
///   immediately after writing.
///   See man page of `fsync(2)` for more details.
pub(all) enum SyncMode {
  NoSync
  Data
  Full
}

///|
/// Open a file. `filename` will be encoded using UTF8.
///
/// - `mode` determines what operations (read/write) are permitted for the file.
///
/// - `sync` determines how data will be synchronized to disk after writing,
///   see `SyncMode` for more details. The default is `NoSync`
///
/// - if `append` is `true` (`false` by default), the file will be opened in append mode.
///
/// - if `create` is present and the file is not present,
///   the file will be created, with its user permission set to value of `create`.
///   User permission is represented as an integer in UNIX permission style.
///   For example, `0o640` means:
///   - the owner of the file can read and write the file (`6`)
///   - users in the owner group of the file can read the file (`4`)
///   - other users can do nothing to the file
///
/// - if `truncate` is `true` (`false` by default), and the file exists,
///   it will be truncated to zero length after opening.
pub async fn open(
  filename : StringView,
  mode~ : Mode,
  sync? : SyncMode = NoSync,
  append? : Bool = false,
  create? : Int,
  truncate? : Bool = false,
) -> File {
  let access = match mode {
    ReadOnly => 0
    WriteOnly => 1
    ReadWrite => 2
  }
  let (create, user_mode) = match create {
    None => (false, 0)
    Some(mode) => (true, mode)
  }
  let sync = match sync {
    NoSync => 0
    Data => 1
    Full => 2
  }
  let io = @event_loop.open(
    filename,
    access,
    create~,
    append~,
    truncate~,
    sync~,
    mode=user_mode,
    context="@fs.open()",
  )
  { io, read_buf: @io.ReaderBuffer::new() }
}

///|
/// Create a new file at `pathname`. `pathname` will be encoded using UTF8.
///
/// - User permission of the new file would be set to `permission`,
///   which is an integer in UNIX style. For example, `0o640` means:
///     - the owner of the file can read and write the file (`6`)
///     - users in the owner group of the file can read the file (`4`)
///     - other users can do nothing to the file
///
/// - `sync` determines how data will be synchronized to disk after writing,
///   see `SyncMode` for more details. The default is `NoSync`
pub async fn create(
  filename : StringView,
  permission~ : Int,
  sync? : SyncMode = NoSync,
) -> File {
  open(filename, mode=WriteOnly, sync~, create=permission, truncate=true)
}

///|
/// `file.read(buf, offset~, len~) read `len` bytes from `file`,
/// store data into `buf`, starting with `offset`.
/// By default, `offset` is `0` and `len` is `buf.length() - offset`.
///
/// The number of data actually read will be returned.
/// The number can be smaller than the requested size for various reasons:
///
/// - EOF is reached before reading all requested data
/// - the file is a named pipe, and not enough data is available
pub impl @io.Reader for File with _direct_read(self, buf, offset~, max_len~) {
  self.io.read(buf, offset~, len=max_len, context="@fs.File::read()")
}

///|
pub impl @io.Reader for File with _get_internal_buffer(self) {
  self.read_buf
}

///|
/// Read from a file at the offset given by `position`.
/// Only seekable files (e.g. regular files and block devices) support this operation,
/// calling `read_at` on unsupported file, such as pipe or socket, result in error.
///
/// This function does not change the cursor for reading/writing the file
/// as a stream (i.e. using API based on `@io.Reader` and `@io.Writer`),
/// so it is safe to perform multiple `read_at` on the same file simutaneously.
///
/// Up to `len` bytes of data will be read into `buf[offset:]`.
/// The number of bytes actually read would be returned.
/// The number of read bytes will be smaller than `len` only when EOF is reached.
pub async fn File::read_at(
  self : File,
  buf : FixedArray[Byte],
  position~ : Int64,
  offset? : Int = 0,
  len? : Int = buf.length() - offset,
) -> Int {
  self.io.read_at(buf, offset~, len~, position~, context="@fs.File::read_at()")
}

///|
pub async fn File::read_exactly_at(
  self : File,
  len : Int,
  position~ : Int64,
) -> Bytes {
  let buf = FixedArray::make(len, b'\x00')
  let n = self.io.read_at(
    buf,
    offset=0,
    len~,
    position~,
    context="@fs.File::read_exactly_at()",
  )
  if n < len {
    raise @io.ReaderClosed
  }
  buf.unsafe_reinterpret_as_bytes()
}

///|
pub impl @io.Writer for File with write_once(self, buf, offset~, len~) {
  self.io.write(buf, offset~, len~, context="@fs.File::write()")
}

///|
/// Write to a file at the offset given by `position`.
/// Only seekable files (e.g. regular files and block devices) support this operation,
/// calling `write_at` on unsupported file, such as pipe or socket, result in error.
///
/// This function does not change the cursor for reading/writing the file
/// as a stream (i.e. using API based on `@io.Reader` and `@io.Writer`),
/// so it is safe to perform multiple `write_at` on the same file simutaneously,
/// as long as the regions they write do not overlap.
///
/// `write_at` would only return after all data is written.
pub async fn File::write_at(
  self : File,
  buf : BytesView,
  position~ : Int64,
) -> Unit {
  self.io.write_at(
    buf.data(),
    offset=buf.start_offset(),
    len=buf.length(),
    position~,
    context="@fs.File::read_at()",
  )
}

///|
/// Flush all in-memory data of an opened file to disk.
/// If `only_data` is `true` (`false` by default),
/// some metadata such as timestamp may not be flushed.
/// Buf file content and important metadata such as file size are always flushed.
pub async fn File::sync(self : File, only_data? : Bool = false) -> Unit {
  self.io.fsync(only_data~, context="@fs.File::sync()")
}

///|
/// The kind of lock that can be acquired on a file.
/// `Exclusive` lock must be unique,
/// while multiple `Shared` lock can coexist.
/// `Exclusive` lock and `Shared` lock are mutually exclusive.
pub(all) enum Lock {
  Shared
  Exclusive
}

///|
/// Lock a file, block until the lock is successfully acquired.
///
/// The lock here is advisory, so normal read/write operations
/// on the file are not affected by the lock,
/// only another attempt to lock the same file may conflict with the lock here.
///
/// The underlying syscall used to implement the lock is undefined.
/// So the lock should only be used for synchronization between multiple process
/// written using `moonbitlang/async`.
pub async fn File::lock(self : File, lock : Lock) -> Unit {
  self.io.lock(exclusive=lock is Exclusive, context="@fs.File::lock()")
}

///|
extern "C" fn errno_is_lock_violation(err : Int) -> Bool = "moonbitlang_async_errno_is_lock_violation"

///|
extern "C" fn try_lock_ffi(fd : @fd_util.Fd, exclusive~ : Bool) -> Int = "moonbitlang_async_try_lock_file"

///|
/// Try to lock a file.
/// If the lock is successfully acquired, `true` is returned.
/// If the lock cannot be acquired immediately
/// (because an incompatible lock is held by another process),
/// `false` is returned immediately.
///
/// The lock here is advisory, so normal read/write operations
/// on the file are not affected by the lock,
/// only another attempt to lock the same file may conflict with the lock here.
///
/// The underlying syscall used to implement the lock is undefined.
/// So the lock should only be used for synchronization between multiple process
/// written using `moonbitlang/async`.
pub fn File::try_lock(self : File, lock : Lock) -> Bool raise {
  let ret = try_lock_ffi(self.fd(), exclusive=lock is Exclusive)
  if ret >= 0 {
    true
  } else if errno_is_lock_violation(@os_error.get_errno()) {
    false
  } else {
    @os_error.check_errno("@fs.File::try_lock()")
    false
  }
}

///|
extern "C" fn unlock_ffi(fd : @fd_util.Fd) -> Int = "moonbitlang_async_unlock_file"

///|
/// Unlock a file that was previously locked by this process.
pub fn File::unlock(self : File) -> Unit {
  if unlock_ffi(self.fd()) < 0 {
    // swallow the error so that we can use `unlock` in `defer`.
    // TODO: remove the `try!` after we support raising error in `defer`.
    try! @os_error.check_errno("@fs.File::unlock()")
  }
}

///|
/// Remove the file located at `path`. `path` is encoded using UTF8.
pub async fn remove(path : StringView) -> Unit {
  @event_loop.remove(path, context="@fs.remove()")
}

///|
/// Get the size of the file. This method will not change position in the file.
/// Can only be applied to a regular file.
pub async fn File::size(self : File) -> Int64 {
  @event_loop.file_size(self.io.fd(), context="@fs.File::size()")
}

///|
#cfg(not(platform="windows"))
extern "C" fn as_dir_ffi(fd : @fd_util.Fd) -> Directory = "fdopendir"

///|
#cfg(not(platform="windows"))
extern "C" fn Directory::is_null(dir : Directory) -> Bool = "moonbitlang_async_dir_is_null"

///|
/// Convert a file to directory.
/// If the file is not a directory, an error will be raised.
///
/// The ownership of the file will be transferred to `as_dir`.
/// The input file will be automatically closed when the
/// result directory object is closed.
/// If `as_dir` fails, the input file will be closed automatically.
#cfg(not(platform="windows"))
#deprecated("`as_dir` is deprecated because it is not portable, use `opendir` instead.")
pub fn File::as_dir(self : File) -> Directory raise {
  let fd = self.io.detach_from_event_loop()
  let dir = as_dir_ffi(fd)
  if dir.is_null() {
    let context = "@fs.File::as_dir()"
    @fd_util.close(fd, kind=self.io.kind(), context~)
    @os_error.check_errno(context)
  }
  dir
}

///|
// mute unused warning
#cfg(platform="windows")
let _unused : Unit = ignore(@os_error.check_errno)

///|
pub fn File::kind(self : File) -> FileKind {
  FileKind::from_fd_util_file_kind(self.io.kind())
}

///|
/// Get the last access time of a file.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
pub async fn File::atime(self : File) -> (Int64, Int) {
  @event_loop.file_time(self.io.fd(), context="@fs.File::atime()").atime()
}

///|
/// Get the last modification time of a file.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
pub async fn File::mtime(self : File) -> (Int64, Int) {
  @event_loop.file_time(self.io.fd(), context="@fs.File::mtime()").mtime()
}

///|
/// Get the last status change time of a file.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
pub async fn File::ctime(self : File) -> (Int64, Int) {
  @event_loop.file_time(self.io.fd(), context="@fs.File::ctime()").ctime()
}

///|
/// Read the contents of the file located at `path`.
/// If `sync_timestamp` is `true` (`false` by default),
/// `read_file` will block until timestamp change is written to the file system.
pub async fn read_file(
  path : StringView,
  sync_timestamp? : Bool = false,
) -> &@io.Data {
  let file = open(path, mode=ReadOnly)
  defer file.close()
  let result = file.read_all()
  if sync_timestamp {
    file.io.fsync(
      only_data=false,
      context="@fs.File::read_file(sync_timestamp=true)",
    )
  }
  result
}

///|
/// Write data to a file located at `path`.
/// The meaning of `sync`, `append`, `create`, and `truncate`,
/// is the same as `open`, except that `truncate` is `true` by default.
/// See `open` for more details.
pub async fn write_file(
  path : StringView,
  content : &@io.Data,
  sync? : SyncMode = Data,
  append? : Bool = false,
  create? : Int,
  truncate? : Bool = true,
) -> Unit {
  let file = open(path, mode=WriteOnly, sync~, append~, create?, truncate~)
  defer file.close()
  file.write(content.binary())
}
