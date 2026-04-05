///|
test "param returns string value" {
  let event = @mocket.MocketEvent::{
    req: { http_method: "GET", url: "/", headers: {}, raw_body: b"" },
    res: @mocket.HttpResponse::new(@mocket.OK),
    params: { "id": "42" },
  }
  inspect(event.param("id"), content="Some(\"42\")")
  inspect(event.param("missing"), content="None")
}

///|
test "param_int parses integer" {
  let event = @mocket.MocketEvent::{
    req: { http_method: "GET", url: "/", headers: {}, raw_body: b"" },
    res: @mocket.HttpResponse::new(@mocket.OK),
    params: { "id": "123" },
  }
  inspect(event.param_int("id"), content="Some(123)")
  inspect(event.param_int("missing"), content="None")
}

///|
test "param_int returns none for non-integer" {
  let event = @mocket.MocketEvent::{
    req: { http_method: "GET", url: "/", headers: {}, raw_body: b"" },
    res: @mocket.HttpResponse::new(@mocket.OK),
    params: { "id": "abc" },
  }
  inspect(event.param_int("id"), content="None")
}
