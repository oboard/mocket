///|
test "custom not found handler is set" {
  let app = @crescent.Mocket()
  app.set_not_found_handler(fn(_event) noraise {
    @crescent.HttpResponse(NotFound).body("Custom 404")
  })
  inspect(app.has_not_found_handler(), content="true")
}

///|
test "not found handler defaults to none" {
  let app = @crescent.Mocket()
  inspect(app.has_not_found_handler(), content="false")
}

///|
test "group merges not found handler" {
  let app = @crescent.Mocket()
  app.group("/api", fn(group) {
    group.set_not_found_handler(fn(_event) noraise {
      @crescent.HttpResponse(NotFound).body("API 404")
    })
  })
  inspect(app.has_not_found_handler(), content="true")
}
