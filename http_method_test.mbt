///|
test "HttpMethod round-trips through string conversion" {
  let meths : Array[@crescent.HttpMethod] = [
    @crescent.Get,
    @crescent.Head,
    @crescent.Post,
    @crescent.Put,
    @crescent.Patch,
    @crescent.Delete,
    @crescent.Options,
    @crescent.Trace,
    @crescent.Connect,
  ]
  for meth in meths {
    let s = meth.to_method_string()
    let back = @crescent.HttpMethod::from_string(s)
    assert_eq(meth, back)
  }
}

///|
test "HttpMethod::from_string handles unknown methods" {
  let custom = @crescent.HttpMethod::from_string("PURGE")
  assert_true(custom is @crescent.Other(_))
  assert_eq(custom.to_method_string(), "PURGE")
}

///|
test "HttpMethod pattern matching in handlers" {
  let req = @crescent.HttpRequest::new(@crescent.Get, "/", {}, raw_body=b"")
  let result = match req.http_method {
    @crescent.Get => "get"
    @crescent.Post => "post"
    _ => "other"
  }
  assert_eq(result, "get")
}

///|
test "HttpMethod string interpolation via Show" {
  let meth : @crescent.HttpMethod = @crescent.Post
  let s = "\{meth}"
  assert_eq(s, "POST")
}
