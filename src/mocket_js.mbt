///|
#external
pub type HttpRequestInternal

///|
#external
pub type HttpResponseInternal

///|
pub extern "js" fn HttpResponseInternal::url(
  self : HttpResponseInternal,
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::url(
  self : HttpRequestInternal,
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::req_method(
  self : HttpRequestInternal,
) -> String = "(s) => s.method"

///|
pub extern "js" fn HttpRequestInternal::on(
  self : HttpRequestInternal,
  event : String,
  handler : (@js.Value) -> Unit,
) -> Unit = "(s, event, handler) => s.on(event, handler)"

///|
pub extern "js" fn HttpRequestInternal::headers(
  self : HttpRequestInternal,
) -> @js.Object = "(s) => s.headers"

///|
pub extern "js" fn HttpResponseInternal::statusCode(
  self : HttpResponseInternal,
) -> Int = "(s) => s.statusCode"

///|
pub extern "js" fn HttpResponseInternal::end(
  self : HttpResponseInternal,
  data : String,
) -> Unit = "(s, data) => s.end(data)"

///|
pub extern "js" fn HttpResponseInternal::write_head(
  self : HttpResponseInternal,
  statusCode : Int,
  headers : @js.Value,
) -> Unit = "(s, statusCode, headers) => s.writeHead(statusCode, headers)"

///|
pub extern "js" fn createServer(
  handler : (HttpRequestInternal, HttpResponseInternal, () -> Unit) -> Unit,
  port : Int,
) -> Unit = "(handler, port) => require('node:http').createServer(handler).listen(port, () => {})"
