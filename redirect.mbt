/// Returns a 301 Moved Permanently redirect response.
///
/// ```mbt check
/// test {
///   let res = @mocket.HttpResponse::redirect("/new-path")
///   inspect(res.status_code, content="MovedPermanently")
///   inspect(res.headers.get("Location"), content="Some(\"/new-path\")")
/// }
/// ```

///|
pub fn HttpResponse::redirect(location : String) -> HttpResponse {
  let res = HttpResponse::new(MovedPermanently)
  res.headers.set("Location", location)
  res
}

/// Returns a 302 Found (temporary) redirect response.

///|
pub fn HttpResponse::redirect_temporary(location : String) -> HttpResponse {
  let res = HttpResponse::new(Found)
  res.headers.set("Location", location)
  res
}

/// Returns a 307 Temporary Redirect response (preserves method).

///|
pub fn HttpResponse::redirect_307(location : String) -> HttpResponse {
  let res = HttpResponse::new(TemporaryRedirect)
  res.headers.set("Location", location)
  res
}

/// Returns a 308 Permanent Redirect response (preserves method).

///|
pub fn HttpResponse::redirect_308(location : String) -> HttpResponse {
  let res = HttpResponse::new(PermanentRedirect)
  res.headers.set("Location", location)
  res
}
