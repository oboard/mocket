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
pub type Directory

///|
pub async fn open_detached(
  path : StringView,
  // 0 => read only, 1 => write only, 2 => read write
  access : Int,
  create~ : Bool,
  append~ : Bool,
  truncate~ : Bool,
  // 0 => no sync, 1 => data sync, 2 => full sync
  sync~ : Int,
  // permission for file when new file is created
  mode~ : Int,
  context~ : String,
) -> (@fd_util.Fd, Int64) {
  let path_bytes = @os_string.encode(path)
  let job = Job::open(
    path_bytes,
    access,
    create~,
    append~,
    truncate~,
    sync~,
    mode~,
  )
  fn cancel(job_id) raise {
    guard curr_loop.val is Some(evloop)
    evloop.cancel_job_in_worker(job_id, context~)
  }

  try perform_job_in_worker(job, context~, cancel~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => (job.get_open_job_result(), job.get_open_job_kind())
  }
}

///|
pub async fn open(
  path : StringView,
  // 0 => read only, 1 => write only, 2 => read write
  access : Int,
  create~ : Bool,
  append~ : Bool,
  truncate~ : Bool,
  // 0 => no sync, 1 => data sync, 2 => full sync
  sync~ : Int,
  // permission for file when new file is created
  mode~ : Int,
  context~ : String,
) -> IoHandle {
  let (fd, kind) = open_detached(
    path,
    access,
    create~,
    append~,
    truncate~,
    sync~,
    mode~,
    context~,
  )
  let kind = @fd_util.FileKind::from_sys_kind(kind)
  // On Windows, due to a lot of complexity,
  // we use synchronous IO + thread pool unconditionally for regular files.
  // However, on Windows, overlapped IO must be enabled on file creation time,
  // but we cannot know the kind of a file before opening it.
  // So, we use synchronous IO unconditionally for everything opened by path,
  // including named pipes.
  IoHandle::from_fd(fd, kind~, is_async=!IS_WINDOWS && kind.can_poll())
}

///|
pub async fn file_kind_by_path(
  path : StringView,
  follow_symlink~ : Bool,
  context~ : String,
) -> @fd_util.FileKind {
  let path_bytes = @os_string.encode(path)
  let job = Job::file_kind_by_path(path_bytes, follow_symlink~)
  try perform_job_in_worker(job, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => @fd_util.FileKind::from_sys_kind(job.get_file_kind_by_path_result())
  }
}

///|
pub async fn file_size(fd : @fd_util.Fd, context~ : String) -> Int64 {
  let job = Job::file_size(fd)
  let _ = perform_job_in_worker(job, context~)
  job.get_file_size_result()
}

///|
pub async fn file_time(
  fd : @fd_util.Fd,
  context~ : String,
) -> @fd_util.FileTime {
  let result = @fd_util.FileTime::new()
  let job = Job::file_time(fd, result)
  let _ = perform_job_in_worker(job, context~)
  result
}

///|
pub async fn file_time_by_path(
  path : StringView,
  follow_symlink~ : Bool,
  context~ : String,
) -> @fd_util.FileTime {
  let path_bytes = @os_string.encode(path)
  let result = @fd_util.FileTime::new()
  let job = Job::file_time_by_path(path_bytes, result, follow_symlink~)
  try perform_job_in_worker(job, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => ()
  }
  result
}

///|
pub async fn access(path : StringView, acc : Access, context~ : String) -> Int {
  let path_bytes = @os_string.encode(path)
  perform_job_in_worker(Job::access(path_bytes, acc), context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  }
}

///|
pub async fn chmod(path : StringView, mode : Int, context~ : String) -> Unit {
  let path_bytes = @os_string.encode(path)
  try perform_job_in_worker(Job::chmod(path_bytes, mode), context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
pub async fn IoHandle::fsync(
  handle : IoHandle,
  only_data~ : Bool,
  context~ : String,
) -> Unit {
  perform_job_in_worker(Job::fsync(handle.fd, only_data), context~) |> ignore
}

///|
pub async fn IoHandle::lock(
  handle : IoHandle,
  exclusive~ : Bool,
  context~ : String,
) -> Unit {
  guard curr_loop.val is Some(evloop)
  perform_job_in_worker(
    Job::flock(handle.fd, exclusive),
    cancel=job_id => evloop.cancel_job_in_worker(job_id, context~),
    context~,
  )
  |> ignore
}

///|
pub async fn remove(path : StringView, context~ : String) -> Unit {
  let path_bytes = @os_string.encode(path)
  try perform_job_in_worker(Job::remove(path_bytes), context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
pub async fn symlink(
  target : StringView,
  path : StringView,
  context~ : String,
) -> Unit {
  let target_bytes = @os_string.encode(target)
  let path_bytes = @os_string.encode(path)
  try
    perform_job_in_worker(Job::symlink(target_bytes, path_bytes), context~)
  catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(
        errno,
        context="\{context}: \{target.escape()} => \{path.escape()}",
      )
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
pub async fn mkdir(path : StringView, mode~ : Int, context~ : String) -> Unit {
  let path_bytes = @os_string.encode(path)
  try perform_job_in_worker(Job::mkdir(path_bytes, mode), context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
pub async fn rmdir(path : StringView, context~ : String) -> Unit {
  let path_bytes = @os_string.encode(path)
  try perform_job_in_worker(Job::rmdir(path_bytes), context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
#cfg(platform="windows")
fn prepare_opendir_path(path : StringView) -> StringView {
  if path is [.., '/' | '\\'] {
    path + "*"
  } else {
    path + "\\*"
  }
}

///|
#cfg(not(platform="windows"))
fn prepare_opendir_path(path : StringView) -> StringView {
  path
}

///|
pub async fn opendir(path : StringView, context~ : String) -> Directory {
  let path_bytes = @os_string.encode(prepare_opendir_path(path))
  let job = Job::opendir(path_bytes)
  let _ = perform_job_in_worker(job, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  }
  job.get_opendir_result()
}

///|
#cfg(not(platform="windows"))
pub extern "C" fn Directory::close(self : Directory) -> Int = "closedir"

///|
#cfg(platform="windows")
pub extern "C" fn Directory::close(self : Directory) -> Int = "moonbitlang_async_closedir"

///|
pub async fn readdir(dir : Directory, context~ : String) -> @c_buffer.Buffer {
  let job = Job::readdir(dir)
  let _ = perform_job_in_worker(job, context~)
  job.get_readdir_result()
}

///|
#cfg(not(platform="windows"))
pub async fn realpath(path : StringView, context~ : String) -> String {
  let path_bytes = @os_string.encode(path)
  let job = Job::realpath(path_bytes)
  let _ = perform_job_in_worker(job, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  }
  let c_path = job.get_realpath_result()
  defer c_path.free()
  @os_string.decode(c_path)
}

///|
#cfg(platform="windows")
pub async fn realpath(path : StringView, context~ : String) -> String {
  let path_bytes = @os_string.encode(path)
  let job = Job::realpath(path_bytes)
  let _ = perform_job_in_worker(job, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{path.escape()}")
    err => raise err
  }
  job.get_realpath_result()
}
