// ///|

///|
using @crescent {trait ServeStaticProvider, trait Responder}

/// A file-system-backed provider for serving static assets. Implements the
/// `ServeStaticProvider` trait to resolve asset metadata and contents from a
/// directory on disk.

///|
pub struct StaticFileProvider {
  priv path : String

  fn new(path~ : String) -> StaticFileProvider
}

/// Creates a new `StaticFileProvider` rooted at the given directory path.

///|
pub fn StaticFileProvider::new(path~ : String) -> StaticFileProvider {
  { path, }
}

///|
fn is_safe_static_id(id : String) -> Bool {
  if id.find("\\") is Some(_) {
    return false
  }
  for segment in id.split("/") {
    if segment == ".." {
      return false
    }
  }
  true
}

///|
fn StaticFileProvider::full_path(
  self : StaticFileProvider,
  id : String,
) -> String? {
  if is_safe_static_id(id) {
    Some(self.path + "/" + id)
  } else {
    None
  }
}

///|
fn static_asset_etag(
  mtime_sec : Int64,
  mtime_nsec : Int,
  size : Int64,
) -> String {
  "\"\{mtime_sec}-\{mtime_nsec}-\{size}\""
}

///|
async fn open_static_asset(path : String) -> @fs.File? noraise {
  try @fs.open(path, mode=ReadOnly) catch {
    _ => None
  } noraise {
    file =>
      if file.kind() is Regular {
        Some(file)
      } else {
        file.close()
        None
      }
  }
}

/// Returns metadata (ETag, modification time, path, size) for the asset
/// identified by `id`, or `None` if the file does not exist or is not a regular file.

///|
pub impl ServeStaticProvider for StaticFileProvider with get_meta(
  self,
  id : String,
) -> @crescent.StaticAssetMeta? {
  match self.full_path(id) {
    Some(path) =>
      match open_static_asset(path) {
        Some(file) => {
          defer file.close()
          match (try? file.size(), try? file.mtime()) {
            (Ok(size), Ok((mtime_sec, mtime_nsec))) =>
              Some(
                @crescent.StaticAssetMeta::new(
                  etag=static_asset_etag(mtime_sec, mtime_nsec, size),
                  mtime=mtime_sec,
                  path~,
                  size~,
                ),
              )
            _ => None
          }
        }
        None => None
      }
    None => None
  }
}

/// Reads and returns the full contents of the static asset identified by `id`
/// as an HTTP response, including `Content-Length` and `ETag` headers.

///|
pub impl ServeStaticProvider for StaticFileProvider with get_contents(
  self,
  id : String,
) -> &Responder {
  match self.full_path(id) {
    Some(path) =>
      match open_static_asset(path) {
        Some(file) => {
          defer file.close()
          let headers = match (try? file.size(), try? file.mtime()) {
            (Ok(size), Ok((mtime_sec, mtime_nsec))) => {
              let headers : Map[String, String] = {}
              headers.set("Content-Length", size.to_string())
              headers.set(
                "ETag",
                static_asset_etag(mtime_sec, mtime_nsec, size),
              )
              headers
            }
            _ => {}
          }
          try file.read_all().binary() catch {
            _ => @crescent.HttpResponse::new(NotFound).body("Not Found")
          } noraise {
            contents => @crescent.HttpResponse::new(OK, headers~).body(contents)
          }
        }
        None => @crescent.HttpResponse::new(NotFound).body("Not Found")
      }
    None => @crescent.HttpResponse::new(NotFound).body("Not Found")
  }
}

/// Returns the MIME type for the given asset identifier. This implementation
/// always returns `None`, deferring type detection to the framework.

///|
pub impl ServeStaticProvider for StaticFileProvider with get_type(_, _ : String) -> String? {
  None
}

/// Returns the content-encoding mappings (e.g. file extension to encoding name).
/// This implementation returns an empty map, indicating no pre-encoded variants.

///|
pub impl ServeStaticProvider for StaticFileProvider with get_encodings(_) -> Map[
  String,
  String,
] {
  {}
}

/// Returns the list of filenames to try when resolving a directory request to an
/// index document (e.g. `"index.html"`, `"index.htm"`).

///|
pub impl ServeStaticProvider for StaticFileProvider with get_index_names(_) -> Array[
  String,
] {
  [
    "index.html", "index.htm", "index.txt", "index.md", "index.json", "index.xml",
    "index.xhtml", "default.html", "default.htm", "home.html", "home.htm",
  ]
}

/// Returns whether unmatched requests should fall through to subsequent
/// middleware. This implementation returns `false`, meaning a 404 is returned
/// for missing assets.

///|
pub impl ServeStaticProvider for StaticFileProvider with get_fallthrough(_) -> Bool {
  false
}
