/// Metadata describing a static asset including its content type, ETag, modification time, and size.

///|
pub(all) struct StaticAssetMeta {
  asset_type : String?
  etag : String?
  mtime : Int64?
  path : String?
  size : Int64?
  encoding : String?

  fn new(
    asset_type? : String,
    etag? : String,
    mtime? : Int64,
    path? : String,
    size? : Int64,
    encoding? : String,
  ) -> StaticAssetMeta
}

/// Creates a new `StaticAssetMeta` with optional fields for asset type, ETag, mtime, path, size, and encoding.

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

/// Trait for providing static file serving capabilities, including asset lookup, content retrieval, and MIME type resolution.

///|
pub(open) trait ServeStaticProvider {
  // This function should resolve asset meta
  async get_meta(Self, id : String) -> StaticAssetMeta? noraise
  // This function should resolve asset content
  async get_contents(Self, id : String) -> &Responder noraise
  // Custom MIME type resolver function
  get_type(Self, ext : String) -> String? noraise
  // Encodings map
  get_encodings(Self) -> Map[String, String] noraise
  // Index names
  get_index_names(Self) -> Array[String] noraise
  // Fallthrough
  get_fallthrough(Self) -> Bool noraise
}

///|
fn normalize_mount_path(path : String) -> String {
  if path == "" {
    "/"
  } else if path.length() > 1 && path[path.length() - 1:] == "/" {
    path[:path.length() - 1].to_string()
  } else {
    path
  }
}

///|
fn mounted_asset_id(mount_path : String, request_path : String) -> String {
  if mount_path == "/" {
    if request_path == "/" {
      ""
    } else {
      request_path[1:].to_string()
    }
  } else if request_path.length() == mount_path.length() {
    ""
  } else {
    request_path[mount_path.length() + 1:].to_string()
  }
}

///|
fn parse_accept_encoding_token(token : StringView) -> String {
  match token.find(";") {
    Some(index) => token[:index].trim(chars=" ").to_string().to_lower()
    None => token.trim(chars=" ").to_string().to_lower()
  }
}

///|
fn normalize_etag_token(token : StringView) -> String {
  let trimmed = token.trim(chars=" ")
  if trimmed.length() >= 2 &&
    (trimmed.has_prefix("W/") || trimmed.has_prefix("w/")) {
    trimmed[2:].trim(chars=" ").to_string()
  } else {
    trimmed.to_string()
  }
}

///|
fn if_none_match_matches(header_value : String, etag : String) -> Bool {
  for token in header_value.split(",") {
    let normalized = normalize_etag_token(token)
    if normalized == "*" || normalized == etag {
      return true
    }
  }
  false
}

///|
struct StaticResolvedResponder {
  inner : &Responder
  asset_headers : Map[String, String]
}

///|
pub impl Responder for StaticResolvedResponder with options(self, res) -> Unit {
  self.inner.options(res)
  if res.status_code == OK {
    self.asset_headers.each((key, value) => {
      if !@mhttp.has_header_case_insensitive(res.headers, key) {
        res.headers.set(key, value)
      }
    })
  }
}

///|
pub impl Responder for StaticResolvedResponder with output(self, buf) -> Unit {
  self.inner.output(buf)
}

///|
pub impl Responder for StaticResolvedResponder with output_bytes(self) -> Bytes? {
  self.inner.output_bytes()
}

///|
fn static_asset_headers(
  provider : &ServeStaticProvider,
  id : String,
  meta : StaticAssetMeta,
) -> Map[String, String] {
  let headers : Map[String, String] = {}
  match meta.etag {
    Some(etag) => headers.set("ETag", etag)
    None => ()
  }
  match meta.mtime {
    Some(mtime) => headers.set("Last-Modified", @mhttp.format_http_date(mtime))
    None => ()
  }
  match meta.asset_type {
    Some(t) => headers.set("Content-Type", t)
    None => {
      let parts = id.split(".").collect()
      if parts.length() > 1 {
        match provider.get_type(parts[parts.length() - 1].to_string()) {
          Some(t) => headers.set("Content-Type", t)
          None => ()
        }
      }
    }
  }
  match meta.encoding {
    Some(enc) => headers.set("Content-Encoding", enc)
    None => ()
  }
  match meta.size {
    Some(size) => headers.set("Content-Length", size.to_string())
    None => ()
  }
  headers
}

///|
fn static_not_modified_headers(
  response_headers : Map[String, String],
  meta : StaticAssetMeta,
) -> Map[String, String] {
  let headers = copy_headers(response_headers)
  match meta.etag {
    Some(etag) => headers.set("ETag", etag)
    None => ()
  }
  match meta.mtime {
    Some(mtime) => headers.set("Last-Modified", @mhttp.format_http_date(mtime))
    None => ()
  }
  headers
}

///|
fn if_modified_since_matches(header_value : String, mtime : Int64) -> Bool {
  match @mhttp.parse_http_date(header_value) {
    Some(if_modified_since) => if_modified_since >= mtime
    None => false
  }
}

/// Mounts a static asset provider at the given path, serving files with ETag/Last-Modified caching and content negotiation.

///|
pub fn Mocket::static_assets(
  self : Mocket,
  path : String,
  provider : &ServeStaticProvider,
) -> Unit {
  let mount_path = normalize_mount_path(self.base_path + path)
  self.use_middleware(
    async fn(event, next) noraise {
      let request_path = event.req.path()
      if !@mhttp.path_scope_matches(mount_path, request_path) {
        return next()
      }

      // Method check
      if event.req.http_method != Get && event.req.http_method != Head {
        if provider.get_fallthrough() {
          return next()
        }
        event.res.headers.set("Allow", "GET, HEAD")
        return HttpResponse::new(MethodNotAllowed)
      }
      let original_id = mounted_asset_id(mount_path, request_path)
      let if_none_match = event.req.get_header("if-none-match")
      let if_modified_since = event.req.get_header("if-modified-since")

      // Parse Accept-Encoding
      // Headers are Map[StringView, StringView]
      let accept_encoding = event.req
        .get_header("accept-encoding")
        .unwrap_or("")
      let encodings = provider.get_encodings()
      let matched_encodings = []
      if !encodings.is_empty() {
        event.res.headers.set("Vary", "Accept-Encoding")
      }
      if accept_encoding != "" {
        // split requires `chars` label
        for pair in accept_encoding.split(",") {
          let encoding = parse_accept_encoding_token(pair)
          match encodings.get(encoding) {
            Some(mapped) => matched_encodings.push(mapped)
            None => ()
          }
        }
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
          return HttpResponse::new(NotFound).body("Not Found")
        }
        Some(meta) => {
          let meta = match meta.etag {
            Some(etag) =>
              if if_none_match.map(header => if_none_match_matches(header, etag)) ==
                Some(true) {
                match provider.get_meta(id) {
                  Some(revalidated_meta) =>
                    match revalidated_meta.etag {
                      Some(revalidated_etag) if revalidated_etag == etag =>
                        return HttpResponse::new(
                          NotModified,
                          headers=static_not_modified_headers(
                            event.res.headers,
                            revalidated_meta,
                          ),
                        )
                      _ => revalidated_meta
                    }
                  None => meta
                }
              } else {
                meta
              }
            None => meta
          }
          let meta = match (if_none_match, if_modified_since, meta.mtime) {
            (None, Some(header), Some(mtime)) if if_modified_since_matches(
                header, mtime,
              ) =>
              match provider.get_meta(id) {
                Some(revalidated_meta) =>
                  match revalidated_meta.mtime {
                    Some(revalidated_mtime) if if_modified_since_matches(
                        header, revalidated_mtime,
                      ) =>
                      return HttpResponse::new(
                        NotModified,
                        headers=static_not_modified_headers(
                          event.res.headers,
                          revalidated_meta,
                        ),
                      )
                    _ => revalidated_meta
                  }
                None => meta
              }
            _ => meta
          }
          let asset_headers = static_asset_headers(provider, id, meta)
          if event.req.http_method == Head {
            let head_headers = copy_headers(event.res.headers)
            asset_headers.each((key, value) => {
              if !@mhttp.has_header_case_insensitive(head_headers, key) {
                head_headers.set(key, value)
              }
            })
            return HttpResponse::new(OK, headers=head_headers)
          }
          let contents = provider.get_contents(id)
          StaticResolvedResponder::{ inner: contents, asset_headers }
        }
      }
    },
    base_path=mount_path,
  )
}
