// Native implementation: all I/O goes through `moonbitlang/async/fs`,
// so requests are served without blocking the event loop.

///|
/// True when `err` means "no such file or path component", i.e. the
/// candidate simply does not exist, as opposed to a real I/O failure.
fn is_not_found_error(err : Error) -> Bool {
  match err {
    @os_error.OSError(_) as e => e.is_ENOENT() || e.is_ENOTDIR()
    _ => false
  }
}

///|
/// Stat a regular file. Returns `None` when the path is absent or is not a
/// regular file (e.g. a directory); raises on any other I/O failure so the
/// caller can surface it as a server error instead of a misleading 404.
pub async fn stat_regular_file(path : String) -> FileStat? {
  let kind = @fs.kind(path) catch {
    err => if is_not_found_error(err) { return None } else { raise err }
  }
  if kind != @fs.FileKind::Regular {
    return None
  }
  let file = @fs.open(path, mode=ReadOnly)
  let size = file.size()
  let (mtime, _) = file.mtime()
  file.close()
  Some({ size, mtime })
}

///|
/// Read an entire file. Returns `None` when the file is absent (e.g. it
/// vanished between stat and read); raises on any other I/O failure.
pub async fn read_file_or_none(path : String) -> Bytes? {
  Some(@fs.read_file(path).binary()) catch {
    err => if is_not_found_error(err) { None } else { raise err }
  }
}
