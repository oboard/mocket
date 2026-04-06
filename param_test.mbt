///|
test "param returns string value" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "42" },
  }
  inspect(event.param("id"), content="Some(\"42\")")
  inspect(event.param("missing"), content="None")
}

///|
test "param_int parses integer" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "123" },
  }
  inspect(event.param_int("id"), content="Some(123)")
  inspect(event.param_int("missing"), content="None")
}

///|
test "param_int returns none for non-integer" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "abc" },
  }
  inspect(event.param_int("id"), content="None")
}

///|
test "require_param returns value when present" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "name": "alice" },
  }
  let name = event.require_param("name")
  assert_eq(name, "alice")
}

///|
test "require_param raises HttpError when missing" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: {},
  }
  let result = try? event.require_param("id")
  assert_true(result is Err(_))
}

///|
test "require_param_int returns parsed integer" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "42" },
  }
  let id = event.require_param_int("id")
  assert_eq(id, 42)
}

///|
test "require_param_int raises on missing param" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: {},
  }
  let result = try? event.require_param_int("id")
  assert_true(result is Err(_))
}

///|
test "require_param_int raises on non-integer value" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "abc" },
  }
  let result = try? event.require_param_int("id")
  assert_true(result is Err(_))
}

///|
test "require_param_int64 returns parsed int64" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "9999999999" },
  }
  let id = event.require_param_int64("id")
  assert_eq(id, 9999999999L)
}

///|
test "require_param_int64 raises on non-integer" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new(Get, "/", {}, raw_body=b""),
    res: @crescent.HttpResponse::new(OK),
    params: { "id": "not-a-number" },
  }
  let result = try? event.require_param_int64("id")
  assert_true(result is Err(_))
}
