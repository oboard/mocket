///|
/// Returns a middleware that sets common security response headers.
pub fn security_headers() -> Middleware {
  async fn(event, next) noraise {
    let res = next()
    event.res.headers.set("X-Content-Type-Options", "nosniff")
    event.res.headers.set("X-Frame-Options", "DENY")
    event.res.headers.set("X-XSS-Protection", "0")
    event.res.headers.set("Referrer-Policy", "strict-origin-when-cross-origin")
    res
  }
}
