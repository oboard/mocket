///|
/// HTTP request methods as a type-safe enum.
///
/// Using this enum instead of raw strings prevents typos like "DLETE" or "OPTONS"
/// and enables pattern matching in handlers.
pub(all) enum HttpMethod {
  Get
  Head
  Post
  Put
  Patch
  Delete
  Options
  Trace
  Connect
  /// For wildcard routing and non-standard methods
  Other(String)
} derive(Eq)

///|
pub impl Show for HttpMethod with output(self, logger) {
  logger.write_string(self.to_method_string())
}

///|
/// Converts the enum to its HTTP method string representation.
pub fn HttpMethod::to_method_string(self : HttpMethod) -> String {
  match self {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Patch => "PATCH"
    Delete => "DELETE"
    Options => "OPTIONS"
    Trace => "TRACE"
    Connect => "CONNECT"
    Other(s) => s
  }
}

///|
/// Parses a string into an HttpMethod.
pub fn HttpMethod::from_string(s : String) -> HttpMethod {
  match s {
    "GET" => Get
    "HEAD" => Head
    "POST" => Post
    "PUT" => Put
    "PATCH" => Patch
    "DELETE" => Delete
    "OPTIONS" => Options
    "TRACE" => Trace
    "CONNECT" => Connect
    other => Other(other)
  }
}
