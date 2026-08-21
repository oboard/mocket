// Native backend: metadata and content are resolved with async filesystem
// I/O via `internal/nativefs` (`moonbitlang/async/fs`), so serving assets
// never blocks the event loop.

///|
using @mocket {trait ServeStaticProvider, trait Responder}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_meta(
  self,
  id : StringView,
) -> @mocket.StaticAssetMeta? {
  let full = self.full_path(id)
  let stat = @nativefs.stat_regular_file(full)
  match stat {
    None => None
    Some({ size, mtime }) => {
      let asset_type = match file_extension(id.to_owned()) {
        Some(ext) => self.get_type(ext)
        None => None
      }
      Some(
        @mocket.StaticAssetMeta::new(
          path=full,
          size~,
          mtime~,
          asset_type?,
          etag="W/\"\{size}-\{mtime}\"",
        ),
      )
    }
  }
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_contents(
  self,
  id : StringView,
) -> &Responder {
  let full = self.full_path(id)
  let bytes = @nativefs.read_file_or_none(full) catch {
    // A real I/O failure (permissions, unreadable device, ...) is a server
    // error, not a missing asset.
    _ =>
      return @mocket.HttpResponse::new(InternalServerError)
        .body("Internal Server Error")
        .to_responder()
  }
  match bytes {
    // The file vanished between get_meta and this read.
    None => @mocket.HttpResponse::new(NotFound).body("Not Found").to_responder()
    // Construct with `raw_body` instead of `body()` so no default
    // Content-Type (application/octet-stream) clobbers the one the
    // middleware already resolved from the file extension.
    Some(bytes) => @mocket.HttpResponse::new(OK, raw_body=bytes).to_responder()
  }
}
