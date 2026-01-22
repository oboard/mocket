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
pub(open) trait ServeStaticProvider {
  // This function should resolve asset meta
  get_meta(Self, id : String) -> StaticAssetMeta?
  // This function should resolve asset content
  get_contents(Self, id : String) -> &Responder
  // Custom MIME type resolver function
  get_type(Self, ext : String) -> String?
  // Encodings map
  get_encodings(Self) -> Map[String, String]
  // Index names
  get_index_names(Self) -> Array[String]
  // Fallthrough
  get_fallthrough(Self) -> Bool
}

///|
pub fn Mocket::static_assets(
  self : Mocket,
  path : String,
  provider : &ServeStaticProvider,
) -> Unit {
  self.use_middleware(async fn(event, next) noraise {
    if not(match_path(path, event.req.url) is None) {
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
    let original_id = event.req.url[path.length():].to_string() catch {
      _ => return next()
    }

    // Parse Accept-Encoding
    // Headers are Map[StringView, StringView]
    let accept_encoding = event.req.headers.get("Accept-Encoding").unwrap_or("")
    let encodings = provider.get_encodings()
    let matched_encodings = []
    if accept_encoding != "" {
      // split requires `chars` label
      for pair in accept_encoding.split(",") {
        let encoding = pair.trim(chars=" ").to_string()
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
    let mut id = original_id
    let mut meta : StaticAssetMeta? = None
    let index_names = provider.get_index_names()
    if index_names.length() == 0 {
      ignore(index_names.push("/index.html"))
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
        let try_id = id + suffix + encoding
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
            if not(event.res.headers.contains("ETag")) {
              event.res.headers.set("ETag", etag)
            }
            if event.req.headers.get("If-None-Match") == Some(etag) {
              return HttpResponse::new(NotModified)
            }
          }
          None => ()
        }

        // Content-Type
        if not(event.res.headers.contains("Content-Type")) {
          match meta.asset_type {
            Some(t) => event.res.headers.set("Content-Type", t)
            None => {
              // Simple extension extraction
              let parts = id.split(".").collect()
              if parts.length() > 1 {
                match provider.get_type(parts[parts.length() - 1].to_string()) {
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
            if not(event.res.headers.contains("Content-Encoding")) {
              event.res.headers.set("Content-Encoding", enc)
            }
          None => ()
        }

        // Content-Length
        match meta.size {
          Some(size) =>
            if size > 0L && not(event.res.headers.contains("Content-Length")) {
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
