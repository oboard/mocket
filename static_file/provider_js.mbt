// JS backend: there is no async filesystem API for the JS target yet, so
// this implementation uses the synchronous `moonbitlang/x/fs` and blocks
// the event loop for the duration of each syscall. Size/mtime metadata is
// unavailable through that API, so responses carry no Content-Length,
// Last-Modified, or ETag on this backend.

///|
using @mocket {trait ServeStaticProvider, trait Responder}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_meta(
  self,
  id : StringView,
) -> @mocket.StaticAssetMeta? {
  let full = self.full_path(id)
  if !@fs.path_exists(full) {
    return None
  }
  let is_file = @fs.is_file(full) catch { _ => return None }
  if !is_file {
    return None
  }
  let asset_type = match file_extension(id.to_owned()) {
    Some(ext) => self.get_type(ext)
    None => None
  }
  Some(@mocket.StaticAssetMeta::new(path=full, asset_type?))
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_contents(
  self,
  id : StringView,
) -> &Responder {
  let full = self.full_path(id)
  let bytes = @fs.read_file_to_bytes(full) catch {
    // x/fs does not expose errno; re-check existence to tell a vanished
    // file (404) apart from a real I/O failure (500).
    _ =>
      return if @fs.path_exists(full) {
        @mocket.HttpResponse::new(InternalServerError)
        .body("Internal Server Error")
        .to_responder()
      } else {
        @mocket.HttpResponse::new(NotFound).body("Not Found").to_responder()
      }
  }
  // See provider_native.mbt for why `raw_body` is used instead of `body()`.
  @mocket.HttpResponse::new(OK, raw_body=bytes).to_responder()
}
