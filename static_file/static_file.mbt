// ///|

///|
using @crescent {trait ServeStaticProvider, trait Responder}

///|
/// A file-system-backed provider for serving static assets. Implements the
/// `ServeStaticProvider` trait to resolve asset metadata and contents from a
/// directory on disk.
pub struct StaticFileProvider {
  priv path : String

  fn new(path~ : String) -> StaticFileProvider
}

///|
/// Creates a new `StaticFileProvider` rooted at the given directory path.
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

/// Canonicalizes `candidate` and verifies it still resides under `root`.
/// Returns `None` if canonicalization fails (file missing) or if the resolved
/// path escapes `root` via symlink. This defends against symlinks inside the
/// static root that point to arbitrary files outside the root.

///|
async fn resolve_within_root(
  root : String,
  candidate : String,
) -> String? noraise {
  let root_real = try? @fs.realpath(root)
  let candidate_real = try? @fs.realpath(candidate)
  match (root_real, candidate_real) {
    (Ok(root_path), Ok(cand_path)) =>
      // Candidate must be equal to root, or under root with a separator.
      if cand_path == root_path || cand_path.has_prefix(root_path + "/") {
        Some(cand_path)
      } else {
        None
      }
    _ => None
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

/// Resolves a static asset id to a canonical path within the provider root,
/// or `None` if the path escapes the root (via symlinks or otherwise).

///|
async fn StaticFileProvider::safe_resolve(
  self : StaticFileProvider,
  id : String,
) -> String? noraise {
  match self.full_path(id) {
    Some(candidate) => resolve_within_root(self.path, candidate)
    None => None
  }
}

///|
/// Returns metadata (ETag, modification time, path, size) for the asset
/// identified by `id`, or `None` if the file does not exist, is not a regular
/// file, or resolves outside the provider root (symlink escape).
pub impl ServeStaticProvider for StaticFileProvider with get_meta(
  self,
  id : String,
) -> @crescent.StaticAssetMeta? {
  match self.safe_resolve(id) {
    Some(path) =>
      match open_static_asset(path) {
        Some(file) => {
          defer file.close()
          match (try? file.size(), try? file.mtime()) {
            (Ok(size), Ok((mtime_sec, mtime_nsec))) =>
              Some(
                @crescent.StaticAssetMeta(
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

///|
/// Reads and returns the full contents of the static asset identified by `id`
/// as an HTTP response, including `Content-Length` and `ETag` headers.
/// Returns 404 if the asset is missing or resolves outside the provider root.
pub impl ServeStaticProvider for StaticFileProvider with get_contents(
  self,
  id : String,
) -> &Responder {
  match self.safe_resolve(id) {
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
            _ => @crescent.HttpResponse(NotFound).body("Not Found")
          } noraise {
            contents => @crescent.HttpResponse(OK, headers~).body(contents)
          }
        }
        None => @crescent.HttpResponse(NotFound).body("Not Found")
      }
    None => @crescent.HttpResponse(NotFound).body("Not Found")
  }
}

///|
/// Returns the MIME type for the given asset identifier. This implementation
/// always returns `None`, deferring type detection to the framework.
pub impl ServeStaticProvider for StaticFileProvider with get_type(_, _ : String) -> String? {
  None
}

///|
/// Returns the content-encoding mappings (e.g. file extension to encoding name).
/// This implementation returns an empty map, indicating no pre-encoded variants.
pub impl ServeStaticProvider for StaticFileProvider with get_encodings(_) -> Map[
  String,
  String,
] {
  {}
}

///|
/// Returns the list of filenames to try when resolving a directory request to an
/// index document (e.g. `"index.html"`, `"index.htm"`).
pub impl ServeStaticProvider for StaticFileProvider with get_index_names(_) -> Array[
  String,
] {
  [
    "index.html", "index.htm", "index.txt", "index.md", "index.json", "index.xml",
    "index.xhtml", "default.html", "default.htm", "home.html", "home.htm",
  ]
}

///|
/// Returns whether unmatched requests should fall through to subsequent
/// middleware. This implementation returns `false`, meaning a 404 is returned
/// for missing assets.
pub impl ServeStaticProvider for StaticFileProvider with get_fallthrough(_) -> Bool {
  false
}
