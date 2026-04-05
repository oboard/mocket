///|
test "custom not found handler is set" {
  let app = @mocket.new()
  app.set_not_found_handler(fn(_event) noraise {
    @mocket.HttpResponse::new(@mocket.NotFound).body("Custom 404")
  })
  inspect(app.not_found_handler is None, content="false")
}

///|
test "not found handler defaults to none" {
  let app = @mocket.new()
  inspect(app.not_found_handler is None, content="true")
}

///|
test "group merges not found handler" {
  let app = @mocket.new()
  app.group("/api", fn(group) {
    group.set_not_found_handler(fn(_event) noraise {
      @mocket.HttpResponse::new(@mocket.NotFound).body("API 404")
    })
  })
  inspect(app.not_found_handler is None, content="false")
}
