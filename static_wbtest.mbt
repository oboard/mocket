///|
/// In-memory `ServeStaticProvider` used to exercise the `static_assets`
/// middleware without touching the filesystem.
priv struct MemProvider {
  files : Map[String, String] // virtual asset id -> content
  mime : Map[String, String] // extension -> MIME type
  fallthrough : Bool
  index_names : Array[String]
  probed : Array[String] // every id passed to get_meta, in order
}

///|
fn MemProvider::new(
  files : Map[String, String],
  fallthrough? : Bool = false,
  index_names? : Array[String] = ["index.html"],
) -> MemProvider {
  { files, mime: { "txt": "text/plain" }, fallthrough, index_names, probed: [] }
}

///|
impl ServeStaticProvider for MemProvider with fn get_meta(self, id) {
  let key = id.to_owned()
  self.probed.push(key)
  match self.files.get(key) {
    Some(content) =>
      Some(
        StaticAssetMeta::new(
          path=key,
          size=content.length().to_int64(),
          mtime=0L,
          etag="\"mem\"",
        ),
      )
    None => None
  }
}

///|
impl ServeStaticProvider for MemProvider with fn get_contents(self, id) {
  match self.files.get(id.to_owned()) {
    // raw_body: keep the Content-Type resolved by the middleware intact
    Some(content) =>
      HttpResponse::new(OK, raw_body=@utf8.encode(content)).to_responder()
    None => HttpResponse::new(NotFound).body("Not Found").to_responder()
  }
}

///|
impl ServeStaticProvider for MemProvider with fn get_type(self, ext) {
  self.mime.get(ext)
}

///|
impl ServeStaticProvider for MemProvider with fn get_encodings(_) {
  {}
}

///|
impl ServeStaticProvider for MemProvider with fn get_index_names(self) {
  self.index_names
}

///|
impl ServeStaticProvider for MemProvider with fn get_fallthrough(self) {
  self.fallthrough
}

///|
fn no_headers() -> Map[@http.CaseInsensitiveString, StringView] {
  {}
}

///|
async fn request(
  app : Mocket,
  http_method : String,
  url : String,
  headers? : Map[@http.CaseInsensitiveString, StringView] = no_headers(),
) -> HttpResponse {
  dispatch_http(app, http_method, url, headers, b"")
}

///|
fn body_string(res : HttpResponse) -> String raise {
  res.read_body()
}

///|
async test "static assets: unrelated and shorter routes pass through" {
  let app = new()
  let provider = MemProvider::new({ "/index.html": "index fixture" })
  app.static_assets("/assets", provider)
  app.get("/api", _ => "api ok")

  // An unrelated route registered after the middleware still runs.
  let res = request(app, "GET", "/api")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "api ok")

  // A URL shorter than the mount must not panic or be intercepted.
  let res = request(app, "GET", "/a")
  assert_eq(res.status_code.to_int(), NotFound.to_int())

  // A URL sharing only a string prefix is outside the mount (segment
  // boundary): the middleware must not even probe the provider.
  let res = request(app, "GET", "/assetsx")
  assert_eq(res.status_code.to_int(), NotFound.to_int())
  assert_eq(provider.probed.length(), 0)
}

///|
async test "static assets: mount root and directory indexes" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({
      "/index.html": "index fixture",
      "/app.txt": "asset fixture",
      "/sub/index.html": "sub index fixture",
    }),
  )

  // The bare mount serves the root index.
  let res = request(app, "GET", "/assets")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "index fixture")

  // So does the mount with a trailing slash.
  let res = request(app, "GET", "/assets/")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "index fixture")

  // A subdirectory serves its own index, with or without trailing slash.
  let res = request(app, "GET", "/assets/sub")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "sub index fixture")
  let res = request(app, "GET", "/assets/sub/")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "sub index fixture")
}

///|
async test "static assets: file serving, MIME type and metadata headers" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({ "/app.txt": "asset fixture" }),
  )
  let res = request(app, "GET", "/assets/app.txt")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "asset fixture")
  assert_eq(res.headers.get("Content-Type"), Some("text/plain"))
  assert_eq(
    res.headers.get("Content-Length"),
    Some("asset fixture".length().to_string()),
  )
  assert_eq(res.headers.get("ETag"), Some("\"mem\""))
}

///|
async test "static assets: HEAD returns headers without a body" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({ "/app.txt": "asset fixture" }),
  )
  let res = request(app, "HEAD", "/assets/app.txt")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(res.raw_body, b"")
  assert_eq(
    res.headers.get("Content-Length"),
    Some("asset fixture".length().to_string()),
  )
}

///|
async test "static assets: conditional request with matching ETag" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({ "/app.txt": "asset fixture" }),
  )
  let headers : Map[@http.CaseInsensitiveString, StringView] = {
    "If-None-Match": "\"mem\"",
  }
  let res = request(app, "GET", "/assets/app.txt", headers~)
  assert_eq(res.status_code.to_int(), NotModified.to_int())
}

///|
async test "static assets: missing assets and unsupported methods" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({ "/app.txt": "asset fixture" }),
  )

  // Without fallthrough, a missing asset under the mount is a 404.
  let res = request(app, "GET", "/assets/missing.txt")
  assert_eq(res.status_code.to_int(), NotFound.to_int())

  // Without fallthrough, methods other than GET/HEAD are rejected.
  let res = request(app, "POST", "/assets/app.txt")
  assert_eq(res.status_code.to_int(), MethodNotAllowed.to_int())
  assert_eq(res.headers.get("Allow"), Some("GET, HEAD"))
}

///|
async test "static assets: fallthrough preserves later handlers" {
  let app = new()
  app.static_assets(
    "/assets",
    MemProvider::new({ "/app.txt": "asset fixture" }, fallthrough=true),
  )
  app.get("/assets/dynamic", _ => "dynamic handler")

  // A missing asset falls through to the router instead of a 404.
  let res = request(app, "GET", "/assets/dynamic")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "dynamic handler")

  // Unsupported methods fall through too.
  let res = request(app, "POST", "/assets/app.txt")
  assert_eq(res.status_code.to_int(), NotFound.to_int())

  // A present asset is still served by the middleware.
  let res = request(app, "GET", "/assets/app.txt")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "asset fixture")
}

///|
async test "static assets: asset ids stay confined to the mount root" {
  let app = new()
  let provider = MemProvider::new({ "/secret.txt": "top secret" })
  app.static_assets("/assets", provider)

  // ".." segments are resolved under a virtual root, never above it: the
  // provider only ever sees normalized, root-confined ids.
  let res = request(app, "GET", "/assets/../../secret.txt")
  assert_eq(res.status_code.to_int(), OK.to_int())
  assert_eq(body_string(res), "top secret")
  for id in provider.probed {
    assert_false(id.contains(".."))
  }
}
