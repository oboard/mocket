///|
#warnings("-unused_async")
async fn benchmark_route_handler(_event : MocketEvent) -> &Responder noraise {
  "ok"
}

///|
async fn benchmark_middleware(
  _event : MocketEvent,
  next : MiddlewareNext,
) -> &Responder noraise {
  next()
}

///|
fn benchmark_router() -> Mocket {
  let app = new()
  app
  ..get("/plaintext", benchmark_route_handler)
  ..get("/api/v1/users/current/profile/settings", benchmark_route_handler)
  ..get("/echo/:name", benchmark_route_handler)
  ..get(
    "/users/:user_id/posts/:post_id/comments/:comment_id", benchmark_route_handler,
  )
  .get("/wild/**", benchmark_route_handler)
  for i in 0..<1000 {
    app.get("/static/\{i}", benchmark_route_handler)
  }
  app
}

///|
fn benchmark_middleware_router() -> Mocket {
  let app = benchmark_router()
  app.use_middleware(benchmark_middleware)
  app.use_middleware(benchmark_middleware, base_path="/api")
  for i in 0..<1000 {
    app.use_middleware(benchmark_middleware, base_path="/static/\{i}")
  }
  app
}

///|
test (bench : @bench.T) {
  let app = benchmark_router()
  bench.bench(name="static route", fn() {
    bench.keep(app.find_route("GET", "/plaintext"))
  })
  bench.bench(name="deep static route", fn() {
    bench.keep(app.find_route("GET", "/api/v1/users/current/profile/settings"))
  })
  bench.bench(name="large static route table", fn() {
    bench.keep(app.find_route("GET", "/static/999"))
  })
  bench.bench(name="single param route", fn() {
    bench.keep(app.find_route("GET", "/echo/moonbit"))
  })
  bench.bench(name="multi param route", fn() {
    bench.keep(app.find_route("GET", "/users/42/posts/99/comments/7"))
  })
  bench.bench(name="deep wildcard route", fn() {
    bench.keep(app.find_route("GET", "/wild/a/b/c/d"))
  })
  bench.bench(name="missing route", fn() {
    bench.keep(app.find_route("GET", "/missing"))
  })
}

///|
test (bench : @bench.T) {
  let app = benchmark_middleware_router()
  bench.bench(name="root middleware", fn() {
    bench.keep(app.match_middlewares("/plaintext"))
  })
  bench.bench(name="nested middleware", fn() {
    bench.keep(app.match_middlewares("/api/v1/users/current/profile/settings"))
  })
  bench.bench(name="large middleware table", fn() {
    bench.keep(app.match_middlewares("/static/999"))
  })
  bench.bench(name="middleware miss", fn() {
    bench.keep(app.match_middlewares("/other"))
  })
}
