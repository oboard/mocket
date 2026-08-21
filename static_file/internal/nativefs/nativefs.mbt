///|
/// Async filesystem helpers backing `oboard/mocket/static_file` on the
/// native backend. Kept in a separate package so the provider package can
/// also import the synchronous `moonbitlang/x/fs` for the JS backend
/// without a package-alias collision.

///|
/// Metadata of a regular file.
pub(all) struct FileStat {
  size : Int64
  mtime : Int64 // seconds since the Unix epoch
}
