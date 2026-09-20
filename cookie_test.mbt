///|
test "async HTTP cookies preserve attributes and extensions" {
  let response = HttpResponse(OK)
  response.set_cookie(
    @http.Cookie(
      "session_id",
      "12345",
      path="/",
      domain="example.com",
      max_age=3600L,
      secure=true,
      http_only=true,
      extensions=["SameSite=None"],
    ),
  )
  @test.assert_eq(response.cookies.length(), 1)
  let cookie = response.cookies[0]
  @test.assert_eq(cookie.name, "session_id")
  @test.assert_eq(cookie.path, Some("/"))
  @test.assert_eq(cookie.domain, Some("example.com"))
  @test.assert_eq(cookie.max_age, Some(3600L))
  @test.assert_eq(cookie.extensions, ["SameSite=None"])
}

///|
test "response retains cookies with the same name and distinct paths" {
  let response = HttpResponse(OK)
  response.set_cookie(@http.Cookie("session", "root", path="/"))
  response.set_cookie(@http.Cookie("session", "api", path="/api"))
  @test.assert_eq(response.cookies.length(), 2)
  @test.assert_eq(response.cookies[0].path, Some("/"))
  @test.assert_eq(response.cookies[1].path, Some("/api"))
}

///|
test "request cookies are parsed as name value pairs" {
  let request = HttpRequest::{
    http_method: "GET",
    url: "/",
    query: "",
    headers: { "Cookie": "session=abc; Path=/ignored; theme=dark" },
    reader: @io.MemoryReader(writer => writer.write(b"")),
  }
  @test.assert_eq(
    request.get_cookie("session").map(item => item.value),
    Some("abc"),
  )
  @test.assert_eq(
    request.get_cookie("Path").map(item => item.value),
    Some("/ignored"),
  )
  @test.assert_eq(
    request.get_cookie("theme").map(item => item.value),
    Some("dark"),
  )
}

///|
test "request cookie parser handles quoted and empty values" {
  let cookies = parse_request_cookie(
    "name=\"value with spaces\"; empty=; ignored",
  )
  @test.assert_eq(
    cookies.get("name").map(item => item.value),
    Some("value with spaces"),
  )
  @test.assert_eq(cookies.get("empty").map(item => item.value), Some(""))
  match cookies.get("ignored") {
    None => ()
    Some(_) => fail("a cookie without '=' must be ignored")
  }
}
