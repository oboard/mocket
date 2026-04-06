///|
/// Returns a 301 Moved Permanently redirect response.
pub fn HttpResponse::redirect(location : String) -> HttpResponse {
  let res = HttpResponse(MovedPermanently)
  res.headers.set("Location", location)
  res
}

///|
/// Returns a 302 Found (temporary) redirect response.
pub fn HttpResponse::redirect_temporary(location : String) -> HttpResponse {
  let res = HttpResponse(Found)
  res.headers.set("Location", location)
  res
}

///|
/// Returns a 307 Temporary Redirect response (preserves method).
pub fn HttpResponse::redirect_307(location : String) -> HttpResponse {
  let res = HttpResponse(TemporaryRedirect)
  res.headers.set("Location", location)
  res
}

///|
/// Returns a 308 Permanent Redirect response (preserves method).
pub fn HttpResponse::redirect_308(location : String) -> HttpResponse {
  let res = HttpResponse(PermanentRedirect)
  res.headers.set("Location", location)
  res
}
