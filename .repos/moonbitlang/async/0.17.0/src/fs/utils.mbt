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
/// Get the kind of a file at `path`.
/// If `path` is a symbolic link and `follow_symlink` is `true` (`true` by default),
/// the kind of the target of the link will be returned.
pub async fn kind(path : StringView, follow_symlink? : Bool = true) -> FileKind {
  @event_loop.file_kind_by_path(path, follow_symlink~, context="@fs.kind()")
  |> FileKind::from_fd_util_file_kind
}

///|
/// Get the last access time of a file at `path`.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
///
/// If `follow_symlink` is `true` (`true` by default) and `path` is a symbolic link,
/// the timestamp of the target of `path` will be returned.
pub async fn atime(
  path : StringView,
  follow_symlink? : Bool = true,
) -> (Int64, Int) {
  @event_loop.file_time_by_path(path, follow_symlink~, context="@fs.atime()").atime()
}

///|
/// Get the last modification time of a file at `path`.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
///
/// If `follow_symlink` is `true` (`true` by default) and `path` is a symbolic link,
/// the timestamp of the target of `path` will be returned.
pub async fn mtime(
  path : StringView,
  follow_symlink? : Bool = true,
) -> (Int64, Int) {
  @event_loop.file_time_by_path(path, follow_symlink~, context="@fs.mtime()").mtime()
}

///|
/// Get the last status change time of a file at `path`.
/// The return value is a pair `(s, ns)`,
/// representing the time of `s` seconds + `ns` nanoseconds.
///
/// If `follow_symlink` is `true` (`true` by default) and `path` is a symbolic link,
/// the timestamp of the target of `path` will be returned.
pub async fn ctime(
  path : StringView,
  follow_symlink? : Bool = true,
) -> (Int64, Int) {
  @event_loop.file_time_by_path(path, follow_symlink~, context="@fs.ctime()").ctime()
}

///|
pub async fn exists(path : StringView) -> Bool {
  try @event_loop.access(path, Exist, context="@fs.exists()") catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => false
    err => raise err
  } noraise {
    _ => true
  }
}

///|
pub async fn can_read(path : StringView) -> Bool {
  try @event_loop.access(path, CanRead, context="@fs.can_read()") catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => false
    @os_error.OSError(_) as err if err.is_EACCES() => false
    err => raise err
  } noraise {
    _ => true
  }
}

///|
pub async fn can_write(path : StringView) -> Bool {
  try @event_loop.access(path, CanWrite, context="@fs.can_write()") catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => false
    @os_error.OSError(_) as err if err.is_EACCES() => false
    err => raise err
  } noraise {
    _ => true
  }
}

///|
pub async fn can_execute(path : StringView) -> Bool {
  try @event_loop.access(path, CanExecute, context="@fs.can_execute()") catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => false
    @os_error.OSError(_) as err if err.is_EACCES() => false
    err => raise err
  } noraise {
    _ => true
  }
}

///|
/// Get the absolute real path of `path`,
/// removing all `..` and `.` in the `path`,
/// and unfold all symbolic links.
///
/// If the path contains cyclic symbolic link,
/// an error will be raised.
pub async fn realpath(path : StringView) -> String {
  @event_loop.realpath(path, context="@fs.realpath()")
}

///|
/// Create a symbolic link to `old_path` at `new_path`.
pub async fn symlink(target~ : StringView, path : StringView) -> Unit {
  @event_loop.symlink(target, path, context="@fs.link()")
}

///|
/// Change the permission of a file.
/// Permission is represented as an integer in UNIX permission style.
/// For example, `0o640` means:
/// - the owner of the file can read and write the file (`6`)
/// - users in the owner group of the file can read the file (`4`)
/// - other users can do nothing to the file
#cfg(not(platform="windows"))
pub async fn chmod(path : StringView, mode : Int) -> Unit {
  @event_loop.chmod(path, mode, context="@fs.chmod()")
}
