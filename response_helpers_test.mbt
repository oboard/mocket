///|
test "ok helper" {
  let res = @crescent.HttpResponse::ok()
  inspect(res.status_code, content="OK")
}

///|
test "not_found helper" {
  let res = @crescent.HttpResponse::not_found()
  inspect(res.status_code, content="NotFound")
}

///|
test "error helper creates json body" {
  let res = @crescent.HttpResponse::error(BadRequest, "Invalid input")
  inspect(res.status_code, content="BadRequest")
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
}

///|
test "fluent header" {
  let res = @crescent.HttpResponse::ok().header("X-Custom", "value")
  inspect(res.headers.get("X-Custom"), content="Some(\"value\")")
}
