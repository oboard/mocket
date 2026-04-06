///|
async test "wrap_error_handler passes through success" {
  let handler = wrap_error_handler(fn(_event) { "ok" })
  let event = MocketEvent::{
    req: HttpRequest::new_request(Get, "/", {}, b""),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  let buf = @buffer.new()
  result.output(buf)
  assert_eq(buf.contents(), @utf8.encode("ok"))
}

///|
async test "wrap_error_handler catches HttpError" {
  let handler = wrap_error_handler(_event => {
    raise HttpError(BadRequest, "name is required")
  })
  let event = MocketEvent::{
    req: HttpRequest::new_request(Get, "/", {}, b""),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  result.options(event.res)
  assert_eq(event.res.status_code, BadRequest)
  let buf = @buffer.new()
  result.output(buf)
  let body = @utf8.decode(buf.contents())
  assert_true(body.contains("name is required"))
  assert_true(body.contains("400"))
}

///|
async test "wrap_error_handler catches JsonDecodeError as 400" {
  let handler = wrap_error_handler(event => {
    let _user : Json = event.req.json()
    "ok"
  })
  let event = MocketEvent::{
    req: HttpRequest::new_request(Post, "/", {}, b"not valid json"),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  result.options(event.res)
  assert_eq(event.res.status_code, BadRequest)
}

///|
async test "wrap_error_handler catches unknown error as 500" {
  let handler = wrap_error_handler(_event => raise NetworkError)
  let event = MocketEvent::{
    req: HttpRequest::new_request(Get, "/", {}, b""),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  result.options(event.res)
  assert_eq(event.res.status_code, InternalServerError)
}

///|
async test "wrap_error_handler catches Failure as 500" {
  let handler = wrap_error_handler(_event => fail("something went wrong"))
  let event = MocketEvent::{
    req: HttpRequest::new_request(Get, "/", {}, b""),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  result.options(event.res)
  assert_eq(event.res.status_code, InternalServerError)
  let buf = @buffer.new()
  result.output(buf)
  let body = @utf8.decode(buf.contents())
  assert_true(body.contains("something went wrong"))
}

///|
async test "HttpError with NotFound status" {
  let handler = wrap_error_handler(_event => {
    raise HttpError(NotFound, "user not found")
  })
  let event = MocketEvent::{
    req: HttpRequest::new_request(Get, "/", {}, b""),
    res: HttpResponse::new(OK),
    params: {},
  }
  let result = handler(event)
  result.options(event.res)
  assert_eq(event.res.status_code, NotFound)
}
