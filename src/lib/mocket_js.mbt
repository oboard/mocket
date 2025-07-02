///|
#external
pub type HttpRequestInternal

///|
#external
pub type HttpResponseInternal

///|
pub extern "js" fn HttpResponseInternal::url(
  self : HttpResponseInternal
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::url(
  self : HttpRequestInternal
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::reqMethod(
  self : HttpRequestInternal
) -> String = "(s) => s.method"

///|
pub extern "js" fn HttpRequestInternal::body(
  self : HttpRequestInternal
) -> String = "(s) => s.body"

///|
pub extern "js" fn HttpRequestInternal::headers(
  self : HttpRequestInternal
) -> @js.Object = "(s) => s.headers"

///|
pub extern "js" fn HttpResponseInternal::statusCode(
  self : HttpResponseInternal
) -> Int = "(s) => s.statusCode"

///|
pub extern "js" fn HttpResponseInternal::end(
  self : HttpResponseInternal,
  data : String
) -> Unit = "(s, data) => s.end(data)"

///|
pub extern "js" fn HttpResponseInternal::writeHead(
  self : HttpResponseInternal,
  statusCode : Int,
  headers : @js.Value
) -> Unit = "(s, statusCode, headers) => s.writeHead(statusCode, headers)"

///|
pub extern "js" fn createServer(
  handler : (HttpRequestInternal, HttpResponseInternal, () -> Unit) -> Unit,
  port : Int
) -> Unit = "(handler, port) => require('node:http').createServer(handler).listen(port, () => {})"
