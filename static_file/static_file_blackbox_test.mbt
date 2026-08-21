// Black-box tests for the filesystem-backed static provider: a real fixture
// tree is created in the test working directory, served through the full
// router + middleware pipeline (`dispatch_http`), and removed afterwards.

///|
priv struct Fixture {
  base : String
  root : String
}

///|
fn Fixture::create(tag : String) -> Fixture raise {
  // Created relative to the test working directory and removed by
  // `cleanup`; the tag and timestamp keep parallel runs apart.
  let base = "static_blackbox_\{tag}_\{@env.now()}"
  let root = "\{base}/public"
  @fs.create_dir(base)
  @fs.create_dir(root)
  @fs.create_dir("\{root}/sub")
  @fs.write_string_to_file("\{root}/index.html", "index fixture")
  @fs.write_string_to_file("\{root}/app.txt", "asset fixture")
  @fs.write_string_to_file("\{root}/sub/index.html", "sub index")
  // Outside the served root: must never be reachable through the mount.
  @fs.write_string_to_file("\{base}/secret.txt", "outside root")
  { base, root }
}

///|
fn Fixture::cleanup(self : Fixture) -> Unit {
  let files = [
    "\{self.root}/index.html",
    "\{self.root}/app.txt",
    "\{self.root}/sub/index.html",
    "\{self.base}/secret.txt",
  ]
  for file in files {
    @fs.remove_file(file) catch {
      _ => ()
    }
  }
  for dir in ["\{self.root}/sub", self.root, self.base] {
    @fs.remove_dir(dir) catch {
      _ => ()
    }
  }
}

///|
async fn get(
  app : @mocket.Mocket,
  url : String,
  headers? : Map[@http.CaseInsensitiveString, StringView] = {},
) -> @mocket.HttpResponse {
  @mocket.dispatch_http(app, "GET", url, headers, b"")
}

///|
fn body_string(res : @mocket.HttpResponse) -> String raise {
  res.read_body()
}

///|
async test "static file provider: issue reproduction table" {
  let fixture = Fixture::create("repro")
  let app = @mocket.new()
  app.static_assets("/assets", new(fixture.root))
  app.get("/api", _ => "api ok")

  // The bare mount serves the root index instead of a 404.
  let res = get(app, "/assets")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "index fixture")
  assert_eq(res.headers.get("Content-Type"), Some("text/html; charset=utf-8"))

  // The mount with a trailing slash serves the root index too.
  let res = get(app, "/assets/")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "index fixture")

  // A file is served with a resolved Content-Type. (Size/mtime/ETag
  // metadata is asserted in the native-only metadata tests: the JS
  // backend's filesystem API cannot provide it.)
  let res = get(app, "/assets/app.txt")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "asset fixture")
  assert_eq(res.headers.get("Content-Type"), Some("text/plain; charset=utf-8"))

  // An unrelated route is not intercepted and does not panic.
  let res = get(app, "/api")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "api ok")

  // Neither is a URL shorter than the mount.
  let res = get(app, "/a")
  assert_eq(res.status_code.to_int(), 404)

  // A missing asset under the mount is a 404.
  let res = get(app, "/assets/missing.txt")
  assert_eq(res.status_code.to_int(), 404)

  // A subdirectory serves its index with or without trailing slash.
  let res = get(app, "/assets/sub")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "sub index")
  let res = get(app, "/assets/sub/")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "sub index")

  // ".." can never escape the served root.
  let res = get(app, "/assets/../secret.txt")
  assert_eq(res.status_code.to_int(), 404)

  fixture.cleanup()
}

///|
async test "static file provider: HEAD and conditional GET" {
  let fixture = Fixture::create("head")
  let app = @mocket.new()
  app.static_assets("/assets", new(fixture.root))

  // HEAD serves the asset's headers with an empty body.
  let res = @mocket.dispatch_http(app, "HEAD", "/assets/app.txt", {}, b"")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(res.raw_body, b"")
  assert_eq(res.headers.get("Content-Type"), Some("text/plain; charset=utf-8"))

  fixture.cleanup()
}

///|
async test "static file provider: methods and fallthrough" {
  let fixture = Fixture::create("fallthrough")

  // Default: no fallthrough — unsupported methods are rejected...
  let app = @mocket.new()
  app.static_assets("/assets", new(fixture.root))
  let res = @mocket.dispatch_http(app, "POST", "/assets/app.txt", {}, b"")
  assert_eq(res.status_code.to_int(), 405)
  assert_eq(res.headers.get("Allow"), Some("GET, HEAD"))

  // ...while with fallthrough they reach the router, and unmatched asset
  // paths keep working for explicit routes.
  let app = @mocket.new()
  app.static_assets("/assets", new(fixture.root, fallthrough=true))
  app.get("/assets/dynamic", _ => "dynamic handler")
  let res = @mocket.dispatch_http(app, "POST", "/assets/app.txt", {}, b"")
  assert_eq(res.status_code.to_int(), 404)
  let res = get(app, "/assets/dynamic")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "dynamic handler")
  let res = get(app, "/assets/app.txt")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(body_string(res), "asset fixture")

  fixture.cleanup()
}
