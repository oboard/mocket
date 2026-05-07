///|
fn test_middleware(label : String, log : Array[String]) -> Middleware {
  (_event, next) => {
    log.push("\{label}:before")
    let responder = next()
    log.push("\{label}:after")
    responder
  }
}

///|
async test "indexed middleware keeps registration order" {
  let app = new()
  let log = []
  app.use_middleware(test_middleware("global-1", log))
  app.use_middleware(test_middleware("api", log), base_path="/api")
  app.use_middleware(test_middleware("global-2", log))
  app.use_middleware(test_middleware("api-users", log), base_path="/api/users")
  app.get("/api/users", _ => "ok")
  ignore(dispatch_http(app, "GET", "/api/users", {}, b""))
  @test.assert_eq(log, [
    "global-1:before", "api:before", "global-2:before", "api-users:before", "api-users:after",
    "global-2:after", "api:after", "global-1:after",
  ])
}

///|
async test "indexed middleware uses path segment boundaries" {
  let app = new()
  let log = []
  app.use_middleware(test_middleware("api", log), base_path="/api")
  app.get("/api", _ => "api")
  app.get("/api/users", _ => "users")
  app.get("/apix", _ => "apix")

  ignore(dispatch_http(app, "GET", "/api", {}, b""))
  ignore(dispatch_http(app, "GET", "/api/users", {}, b""))
  ignore(dispatch_http(app, "GET", "/apix", {}, b""))

  @test.assert_eq(log, ["api:before", "api:after", "api:before", "api:after"])
}

///|
async test "indexed middleware skips unrelated prefixes" {
  let app = new()
  let log = []
  app.use_middleware(test_middleware("global", log))
  app.use_middleware(test_middleware("api", log), base_path="/api")
  for i = 0; i < 50; i = i + 1 {
    app.use_middleware(test_middleware("x\{i}", log), base_path="/x\{i}")
  }
  app.get("/api/users", _ => "users")

  ignore(dispatch_http(app, "GET", "/api/users", {}, b""))

  @test.assert_eq(log, [
    "global:before", "api:before", "api:after", "global:after",
  ])
}

///|
async test "indexed middleware reorders group registrations globally" {
  let app = new()
  let log = []
  app.use_middleware(test_middleware("global-1", log))
  app.group("/api", group => {
    group.use_middleware(test_middleware("group", log))
    group.get("/users", _ => "users")
  })
  app.use_middleware(test_middleware("global-2", log))

  ignore(dispatch_http(app, "GET", "/api/users", {}, b""))

  @test.assert_eq(log, [
    "global-1:before", "group:before", "global-2:before", "global-2:after", "group:after",
    "global-1:after",
  ])
}
