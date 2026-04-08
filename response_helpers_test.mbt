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

///|
test "body() sets Content-Type from responder" {
  let res = @crescent.HttpResponse::ok().body(@crescent.html("<h1>Hi</h1>"))
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"text/html; charset=utf-8\")",
  )
}

///|
test "header() is case-insensitive" {
  let res = @crescent.HttpResponse::ok()
    .header("content-type", "text/plain")
    .header("Content-Type", "text/html")
  // Only one entry should exist (replaced, not duplicated)
  let mut count = 0
  res.headers.each(fn(k, _v) {
    if k.to_lower() == "content-type" {
      count = count + 1
    }
  })
  assert_eq(count, 1)
}

///|
test "json() sets Content-Type" {
  let res = @crescent.HttpResponse::ok().json(({ "a": 1 } : Json))
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
}
