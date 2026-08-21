// ///|

///|
/// Serves static assets from a directory on the local filesystem.
///
/// On the native backend all filesystem access goes through
/// `moonbitlang/async/fs`, so requests are served without blocking the
/// event loop. On the JS backend there is no async filesystem API yet, so
/// the provider falls back to the synchronous `moonbitlang/x/fs` and blocks
/// for the duration of each syscall.
pub struct StaticFileProvider {
  path : String
  fallthrough : Bool
  index_names : Array[String]
}

///|
/// The index file names probed for directory requests, in order.
pub let default_index_names : Array[String] = [
  "index.html", "index.htm", "index.txt", "index.md", "index.json", "index.xml",
  "index.xhtml", "default.html", "default.htm", "home.html", "home.htm",
]

///|
pub fn new(
  path : String,
  fallthrough? : Bool = false,
  index_names? : Array[String] = default_index_names,
) -> StaticFileProvider {
  { path, fallthrough, index_names }
}

///|
/// Join the provider root and a virtual asset id (always starts with "/").
fn StaticFileProvider::full_path(
  self : StaticFileProvider,
  id : StringView,
) -> String {
  "\{self.path}\{id}"
}

///|
/// Extract the lowercased file extension of an asset id, if it has one.
fn file_extension(id : String) -> String? {
  let last_segment = match id.rev_find("/") {
    Some(i) => id[i + 1:]
    None => id.view()
  }
  match last_segment.rev_find(".") {
    // A leading dot is a hidden file, not an extension.
    Some(i) if i > 0 => Some(last_segment[i + 1:].to_lower().to_owned())
    _ => None
  }
}

///|
test "file_extension" {
  inspect(file_extension("/assets/app.txt"), content="Some(txt)")
  inspect(file_extension("/assets/App.HTML"), content="Some(html)")
  inspect(file_extension("/assets/noext"), content="None")
  inspect(file_extension("/assets/.hidden"), content="None")
  inspect(file_extension("/assets.d/file"), content="None")
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_type(
  _,
  ext : String,
) -> String? {
  mime_type_of(ext)
}

///|
/// A small built-in MIME table covering common web assets.
pub fn mime_type_of(ext : String) -> String? {
  match ext.to_lower() {
    "html" | "htm" | "xhtml" => Some("text/html; charset=utf-8")
    "css" => Some("text/css; charset=utf-8")
    "js" | "mjs" | "cjs" => Some("text/javascript; charset=utf-8")
    "json" | "map" => Some("application/json")
    "txt" => Some("text/plain; charset=utf-8")
    "md" => Some("text/markdown; charset=utf-8")
    "xml" => Some("application/xml")
    "csv" => Some("text/csv; charset=utf-8")
    "pdf" => Some("application/pdf")
    "wasm" => Some("application/wasm")
    "png" => Some("image/png")
    "jpg" | "jpeg" => Some("image/jpeg")
    "gif" => Some("image/gif")
    "webp" => Some("image/webp")
    "avif" => Some("image/avif")
    "svg" => Some("image/svg+xml")
    "ico" => Some("image/x-icon")
    "bmp" => Some("image/bmp")
    "tif" | "tiff" => Some("image/tiff")
    "mp3" => Some("audio/mpeg")
    "wav" => Some("audio/wav")
    "ogg" => Some("audio/ogg")
    "mp4" | "m4v" => Some("video/mp4")
    "webm" => Some("video/webm")
    "woff" => Some("font/woff")
    "woff2" => Some("font/woff2")
    "ttf" => Some("font/ttf")
    "otf" => Some("font/otf")
    "gz" => Some("application/gzip")
    "zip" => Some("application/zip")
    "tar" => Some("application/x-tar")
    _ => None
  }
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_encodings(_) -> Map[
  String,
  String,
] {
  {}
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_index_names(
  self,
) -> Array[String] {
  self.index_names
}

///|
pub impl ServeStaticProvider for StaticFileProvider with fn get_fallthrough(
  self,
) -> Bool {
  self.fallthrough
}
