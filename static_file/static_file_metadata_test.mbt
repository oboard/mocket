// Native-only metadata tests: the JS backend's filesystem API
// (`moonbitlang/x/fs`) cannot report file size or modification time, so
// Content-Length, ETag, and conditional requests are only available on the
// native backend.

///|
async test "static file provider: size, mtime and ETag metadata" {
  let fixture = Fixture::create("metadata")
  let app = @mocket.new()
  app.static_assets("/assets", new(fixture.root))

  // GET carries real Content-Length and a weak ETag.
  let res = get(app, "/assets/app.txt")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(res.headers.get("Content-Length"), Some("13"))
  guard res.headers.get("ETag") is Some(etag) else {
    fail("expected an ETag header")
  }

  // HEAD carries the same metadata with an empty body.
  let res = @mocket.dispatch_http(app, "HEAD", "/assets/app.txt", {}, b"")
  assert_eq(res.status_code.to_int(), 200)
  assert_eq(res.raw_body, b"")
  assert_eq(res.headers.get("Content-Length"), Some("13"))

  // The ETag validates a conditional request.
  let headers : Map[@http.CaseInsensitiveString, StringView] = {
    "If-None-Match": etag,
  }
  let res = get(app, "/assets/app.txt", headers~)
  assert_eq(res.status_code.to_int(), 304)

  fixture.cleanup()
}
