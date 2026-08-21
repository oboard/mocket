///|
pub suberror IOError

///|
pub suberror NetworkError

///|
pub suberror ExecError

///|
// 请求错误处理器：接收事件和未捕获的错误，返回一个响应。
// 用于记录日志、返回自定义错误响应等。
pub type ErrorHandler = (MocketEvent, Error) -> &Responder

///|
// 默认错误处理器：返回 500 Internal Server Error 并附带错误信息。
fn default_error_handler(_event : MocketEvent, err : Error) -> &Responder {
  HttpResponse::new(InternalServerError).body(err.to_string())
}

///|
// 将未捕获的请求错误转换为响应，优先使用用户注册的错误处理器。
fn Mocket::handle_request_error(
  self : Mocket,
  event : MocketEvent,
  err : Error,
) -> &Responder {
  (self.error_handler)(event, err)
}

///|
// 注册请求错误处理器，用于记录日志或返回自定义错误响应。
pub fn Mocket::on_error(self : Mocket, handler : ErrorHandler) -> Unit {
  self.error_handler = handler
}
