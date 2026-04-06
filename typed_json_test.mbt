///|
struct TestUser {
  name : String
  age : Int
} derive(FromJson, ToJson, Eq)

///|
impl Show for TestUser with output(self, logger) {
  logger.write_string("TestUser { name: ")
  logger.write_object(self.name)
  logger.write_string(", age: ")
  logger.write_object(self.age)
  logger.write_string(" }")
}

///|
test "HttpRequest::json parses struct from body" {
  let req = @crescent.HttpRequest::new(
    Post,
    "/users",
    {},
    raw_body=b"{\"name\":\"Alice\",\"age\":30}",
  )
  let user : TestUser = req.json()
  assert_eq(user, { name: "Alice", age: 30 })
}

///|
test "HttpRequest::json fails on invalid json" {
  let req = @crescent.HttpRequest::new(Post, "/users", {}, raw_body=b"not json")
  let result : Result[TestUser, _] = try? req.json()
  assert_true(result is Err(_))
}

///|
test "HttpRequest::json fails on missing fields" {
  let req = @crescent.HttpRequest::new(
    Post,
    "/users",
    {},
    raw_body=b"{\"name\":\"Alice\"}",
  )
  let result : Result[TestUser, _] = try? req.json()
  assert_true(result is Err(_))
}

///|
test "HttpRequest::json fails on wrong field type" {
  let req = @crescent.HttpRequest::new(
    Post,
    "/users",
    {},
    raw_body=b"{\"name\":\"Alice\",\"age\":\"thirty\"}",
  )
  let result : Result[TestUser, _] = try? req.json()
  assert_true(result is Err(_))
}

///|
test "HttpRequest::json parses nested struct" {
  let req = @crescent.HttpRequest::new(
    Post,
    "/",
    {},
    raw_body=b"{\"name\":\"Bob\",\"age\":25}",
  )
  let user : TestUser = req.json()
  assert_eq(user.name, "Bob")
  assert_eq(user.age, 25)
}

///|
test "HttpRequest::json parses empty body as error" {
  let req = @crescent.HttpRequest::new(Post, "/", {}, raw_body=b"")
  let result : Result[TestUser, _] = try? req.json()
  assert_true(result is Err(_))
}

///|
test "HttpResponse::json_value sets content type and body" {
  let user : TestUser = { name: "Alice", age: 30 }
  let res = @crescent.HttpResponse::ok().json_value(user)
  inspect(res.status_code, content="OK")
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
  inspect(@utf8.decode(res.raw_body), content="{\"name\":\"Alice\",\"age\":30}")
}

///|
test "HttpResponse::json_value with array" {
  let users : Array[TestUser] = [
    { name: "Alice", age: 30 },
    { name: "Bob", age: 25 },
  ]
  let res = @crescent.HttpResponse::ok().json_value(users)
  inspect(
    @utf8.decode(res.raw_body),
    content="[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]",
  )
}
