///|
pub(all) struct StaticAssetMeta {
  asset_type : String?
  etag : String?
  mtime : Int64?
  path : String?
  size : Int64?
  encoding : String?
}

///|
pub fn StaticAssetMeta::new(
  asset_type? : String,
  etag? : String,
  mtime? : Int64,
  path? : String,
  size? : Int64,
  encoding? : String,
) -> Self {
  { asset_type, etag, mtime, path, size, encoding }
}

///|
/// A backend for `Mocket::static_assets`.
///
/// Asset ids handed to the provider are virtual absolute paths rooted at the
/// mount point: they always start with "/" and are already normalized, so
/// "." / ".." segments can never escape the provider's root. Providers should
/// join the id onto their root directly.
pub(open) trait ServeStaticProvider {
  // Resolve metadata for a candidate asset id.
  //
  // Return `None` only when the candidate does not exist (or is not a
  // servable asset, e.g. a directory); the middleware then keeps probing the
  // remaining candidates. I/O failures other than absence should be raised
  // so they surface as server errors instead of a misleading 404.
  async fn get_meta(Self, id : StringView) -> StaticAssetMeta?
  // Resolve asset content. Called only after `get_meta` returned `Some` for
  // the same id; a missing file at this point should still yield a 404
  // responder, while other I/O failures should yield a 5xx responder.
  async fn get_contents(Self, id : StringView) -> &Responder
  // Custom MIME type resolver function
  fn get_type(Self, ext : String) -> String?
  // Encodings map
  fn get_encodings(Self) -> Map[String, String]
  // Index names
  fn get_index_names(Self) -> Array[String]
  // Fallthrough
  fn get_fallthrough(Self) -> Bool
}

///|
test "normalize_path" {
  inspect(@posix.Path::normalize("/foo/bar"), content="/foo/bar")
  inspect(@posix.Path::normalize("/foo/../bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/./bar"), content="/foo/bar")
  inspect(@posix.Path::normalize("/foo/../../bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/./../bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/.././bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/./.././bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/.././../bar"), content="/bar")
  inspect(@posix.Path::normalize("/foo/./.././../bar"), content="/bar")
  inspect(@posix.Path::normalize("/../../bar"), content="/bar")
  inspect(@posix.Path::normalize("/.."), content="/")
  inspect(@posix.Path::normalize("/foo/bar/.."), content="/foo")
  inspect(@posix.Path::normalize("/foo/bar/../."), content="/foo")
  inspect(@posix.Path::normalize("/"), content="/")
  inspect(@posix.Path::normalize("foo/bar"), content="foo/bar")
  inspect(@posix.Path::normalize("/foo//bar"), content="/foo/bar")
}

///|
/// Join a candidate suffix (usually an index file name) onto a resolved
/// asset id, inserting exactly one path separator between them.
fn join_asset_id(id : String, suffix : String) -> String {
  if suffix == "" {
    return id
  }
  let suffix = if suffix.has_prefix("/") { suffix[1:] } else { suffix.view() }
  if id.has_suffix("/") {
    "\{id}\{suffix}"
  } else {
    "\{id}/\{suffix}"
  }
}

///|
test "join_asset_id" {
  inspect(join_asset_id("/", "index.html"), content="/index.html")
  inspect(join_asset_id("/app.txt", ""), content="/app.txt")
  inspect(join_asset_id("/sub", "index.html"), content="/sub/index.html")
  inspect(join_asset_id("/sub/", "/index.html"), content="/sub/index.html")
}

///|
pub fn Mocket::static_assets(
  self : Mocket,
  path : String,
  provider : &ServeStaticProvider,
) -> Unit {
  // Normalize the mount point: strip a trailing "/" (except for the root
  // mount "/") so matching and slicing have a single canonical form.
  let mount = if path.length() > 1 && path.has_suffix("/") {
    path[:path.length() - 1].to_owned()
  } else {
    path
  }
  self.use_middleware(async fn(event, next) {
    let url = event.req.url
    // Match the mount as a path prefix on a segment boundary, before any
    // slicing happens: "/assets" matches "/assets" and everything under
    // "/assets/...", but not "/assetsx" or shorter, unrelated URLs. Those
    // fall through to the next middleware or route untouched.
    let in_mount = if mount == "/" {
      url.has_prefix("/")
    } else {
      url == mount || url.has_prefix("\{mount}/")
    }
    if !in_mount {
      return next()
    }

    // Method check
    if event.req.http_method != "GET" && event.req.http_method != "HEAD" {
      if provider.get_fallthrough() {
        return next()
      }
      event.res.headers.set("Allow", "GET, HEAD")
      return HttpResponse::new(MethodNotAllowed)
    }

    // Safe to slice now: `url` equals the mount or starts with "mount/".
    let raw_id = if mount == "/" { url.view() } else { url[mount.length():] }
    // Resolve under a virtual root so ".." segments can never escape it;
    // the normalized id is an absolute path confined to the mount root.
    let resolved_id = Show::to_string(
      @posix.Path::normalize(
        (if raw_id == "" { "/".view() } else { raw_id }).to_owned(),
      ),
    )
    // Parse Accept-Encoding
    let accept_encoding = event.req.headers.get("Accept-Encoding").unwrap_or("")
    let encodings = provider.get_encodings()
    let matched_encodings = []
    if accept_encoding != "" {
      // split requires `chars` label
      for pair in accept_encoding.split(",") {
        let encoding = pair.trim(chars=" ").to_owned()
        match encodings.get(encoding) {
          Some(mapped) => matched_encodings.push(mapped)
          None => ()
        }
      }
    }
    if matched_encodings.length() > 1 {
      event.res.headers.set("Vary", "Accept-Encoding")
    }

    // Search paths
    let mut id = resolved_id
    let mut meta : StaticAssetMeta? = None
    let index_names = {
      let names = provider.get_index_names()
      if names.is_empty() {
        ["index.html"]
      } else {
        names
      }
    }

    // Search logic: suffix -> encoding
    let mut found = false
    let suffixes = [""]
    suffixes.append(index_names)
    let try_encodings = matched_encodings.copy()
    try_encodings.push("") // Add empty encoding (identity)
    for suffix in suffixes {
      if found {
        break
      }
      for encoding in try_encodings {
        let try_id = join_asset_id(id, suffix) + encoding
        match provider.get_meta(try_id) {
          Some(m) => {
            meta = Some(m)
            id = try_id
            found = true
            break
          }
          None => ()
        }
      }
    }
    match meta {
      None => {
        if provider.get_fallthrough() {
          return next()
        }
        return HttpResponse::new(NotFound)
      }
      Some(meta) => {
        // Handle caching
        match meta.mtime {
          Some(_mtime) =>
            // TODO: Date parsing/comparison is tricky without a library. 
            // For now, we just set Last-Modified.
            // event.res.headers.set("Last-Modified", ... )
            ()
          None => ()
        }
        match meta.etag {
          Some(etag) => {
            if !event.res.headers.contains("ETag") {
              event.res.headers.set("ETag", etag)
            }
            if event.req.headers.get("If-None-Match") == Some(etag) {
              return HttpResponse::new(NotModified)
            }
          }
          None => ()
        }

        // Content-Type
        if !event.res.headers.contains("Content-Type") {
          match meta.asset_type {
            Some(t) => event.res.headers.set("Content-Type", t)
            None => {
              // Simple extension extraction
              let parts = id.split(".").collect()
              if parts.length() > 1 {
                match provider.get_type(parts[parts.length() - 1].to_owned()) {
                  Some(t) => event.res.headers.set("Content-Type", t)
                  None => ()
                }
              }
            }
          }
        }

        // Content-Encoding
        match meta.encoding {
          Some(enc) =>
            if !event.res.headers.contains("Content-Encoding") {
              event.res.headers.set("Content-Encoding", enc)
            }
          None => ()
        }

        // Content-Length
        match meta.size {
          Some(size) =>
            if size >= 0L && !event.res.headers.contains("Content-Length") {
              event.res.headers.set("Content-Length", size.to_string())
            }
          None => ()
        }
        if event.req.http_method == "HEAD" {
          return HttpResponse::new(OK)
        }
        let contents = provider.get_contents(id)
        event.res.status_code = OK
        contents
      }
    }
  })
}
