# Crescent — Type-Checked Examples

These examples are verified by `moon check`. See [README.md](README.md) for the full documentation.

## Response Helpers

```mbt
test "response helpers" {
  let ok = @crescent.HttpResponse::ok()
  assert_eq(ok.status_code, @crescent.OK)

  let created = @crescent.HttpResponse::created()
  assert_eq(created.status_code, @crescent.Created)

  let not_found = @crescent.HttpResponse::not_found()
  assert_eq(not_found.status_code, @crescent.NotFound)

  let no_content = @crescent.HttpResponse::no_content()
  assert_eq(no_content.status_code, @crescent.NoContent)

  let bad_request = @crescent.HttpResponse::bad_request()
  assert_eq(bad_request.status_code, @crescent.BadRequest)
}
```

## Fluent Response Building

```mbt
test "fluent response building" {
  let res = @crescent.HttpResponse::ok()
    .header("X-Custom", "value")
    .header("Cache-Control", "max-age=3600")
  assert_eq(res.headers.get("X-Custom"), Some("value"))
  assert_eq(res.headers.get("Cache-Control"), Some("max-age=3600"))
}
```

## Typed JSON Serialization

```mbt
struct User {
  name : String
  age : Int
} derive(ToJson, FromJson, Eq)

test "json_value sets content-type and serializes body" {
  let user = User::{ name: "Alice", age: 30 }
  let res = @crescent.HttpResponse::ok().json_value(user)
  assert_eq(
    res.headers.get("Content-Type"),
    Some("application/json; charset=utf-8"),
  )
  assert_eq(
    @utf8.decode(res.raw_body),
    "{\"name\":\"Alice\",\"age\":30}",
  )
}
```

## HttpMethod Enum

```mbt
test "HttpMethod round-trip" {
  let meth : @crescent.HttpMethod = @crescent.Post
  assert_eq(meth.to_method_string(), "POST")
  assert_eq(@crescent.HttpMethod::from_string("POST"), @crescent.Post)
}

test "HttpMethod pattern matching" {
  let req = @crescent.HttpRequest::new_request(@crescent.Get, "/", {}, b"")
  let label = match req.http_method {
    @crescent.Get => "read"
    @crescent.Post => "write"
    _ => "other"
  }
  assert_eq(label, "read")
}
```

## JSON Parsing

```mbt
struct CreateUser {
  name : String
  age : Int
} derive(FromJson)

test "json parsing from request body" {
  let req = @crescent.HttpRequest::new_request(
    @crescent.Post,
    "/users",
    {},
    b"{\"name\":\"Bob\",\"age\":25}",
  )
  let user : CreateUser = req.json()
  assert_eq(user.name, "Bob")
  assert_eq(user.age, 25)
}

test "try_json returns Result" {
  let req = @crescent.HttpRequest::new_request(
    @crescent.Post,
    "/",
    {},
    b"not json",
  )
  let result : Result[CreateUser, String] = req.try_json()
  assert_true(result is Err(_))
}
```

## Parameter Extraction

```mbt
test "param and param_int" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new_request(@crescent.Get, "/", {}, b""),
    res: @crescent.HttpResponse::new(@crescent.OK),
    params: { "id": "42", "name": "alice" },
  }
  assert_eq(event.param("name"), Some("alice"))
  assert_eq(event.param_int("id"), Some(42))
  assert_eq(event.param("missing"), None)
}

test "require_param raises on missing" {
  let event = @crescent.MocketEvent::{
    req: @crescent.HttpRequest::new_request(@crescent.Get, "/", {}, b""),
    res: @crescent.HttpResponse::new(@crescent.OK),
    params: {},
  }
  let result = try? event.require_param_int("id")
  assert_true(result is Err(_))
}
```

## Request Path and Query Caching

```mbt
test "path is cached after first access" {
  let req = @crescent.HttpRequest::new_request(
    @crescent.Get,
    "/api/users?q=test",
    {},
    b"",
  )
  assert_eq(req.cached_path, None)
  let path = req.path()
  assert_eq(path, "/api/users")
  // Cached on second access
  assert_eq(req.cached_path, Some("/api/users"))
}

test "query_params cached and decoded" {
  let req = @crescent.HttpRequest::new_request(
    @crescent.Get,
    "/search?q=hello%20world&lang=en",
    {},
    b"",
  )
  assert_eq(req.get_query("q"), Some("hello world"))
  assert_eq(req.get_query("lang"), Some("en"))
  assert_eq(req.get_query("missing"), None)
}
```

## Route Pattern Compilation

```mbt
test "compiled route matching" {
  let route = @crescent.CompiledRoute::compile("/users/:id/posts/:postId")
  assert_eq(
    route.match_path("/users/42/posts/99"),
    Some({ "id": "42", "postId": "99" }),
  )
  assert_eq(route.match_path("/users/42"), None)
}

test "static routes are flagged" {
  let static_route = @crescent.CompiledRoute::compile("/api/health")
  assert_true(static_route.is_static)
  let dynamic_route = @crescent.CompiledRoute::compile("/api/:version")
  assert_true(dynamic_route.is_static == false)
}
```

## Routing and TestClient

```mbt
async test "basic routing with TestClient" {
  let app = @crescent.new()
  app.get_raw("/hello", fn(_) noraise { "Hello, World!" })
  app.get_raw("/json", fn(_) noraise {
    @crescent.HttpResponse::ok().json_value(({ "status": "ok" } : Json))
  })
  let client = @crescent.TestClient::new(app)

  let res = client.get("/hello")
  assert_eq(res.status, @crescent.OK)
  assert_eq(res.body_text(), "Hello, World!")

  let res2 = client.get("/json")
  assert_true(res2.body_text().contains("ok"))
}
```

## Typed Handlers with Error Mapping

```mbt
struct TodoInput {
  title : String
} derive(FromJson, ToJson)

async test "typed handler auto-maps errors" {
  let app = @crescent.new()
  app.post("/todos", event => {
    let input : TodoInput = event.json()
    @crescent.HttpResponse::created().json_value(input)
  })
  let client = @crescent.TestClient::new(app)

  // Valid request
  let res = client.post("/todos", body=b"{\"title\":\"Learn MoonBit\"}")
  assert_eq(res.status, @crescent.Created)

  // Invalid JSON -> automatic 400
  let res2 = client.post("/todos", body=b"not json")
  assert_eq(res2.status, @crescent.BadRequest)
}
```

## Middleware

```mbt
async test "security headers middleware" {
  let app = @crescent.new()
  app.use_middleware(@crescent.security_headers())
  app.get_raw("/test", fn(_) noraise { "ok" })
  let client = @crescent.TestClient::new(app)
  let res = client.get("/test")
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
  assert_eq(res.headers.get("X-Frame-Options"), Some("DENY"))
}

async test "request ID middleware" {
  let app = @crescent.new()
  app.use_middleware(@crescent.request_id())
  app.get_raw("/test", fn(_) noraise { "ok" })
  let client = @crescent.TestClient::new(app)
  let res = client.get("/test")
  assert_true(res.headers.get("X-Request-Id") is Some(_))
}
```

## RESTful Resource

```mbt
struct Item {
  id : Int
  name : String
} derive(ToJson, FromJson, Eq)

impl Show for Item with output(self, logger) {
  logger.write_string("Item(\{self.id}, \{self.name})")
}

struct CreateItemInput {
  name : String
} derive(FromJson, ToJson)

async test "resource CRUD" {
  let items : Array[Item] = [{ id: 1, name: "Alpha" }]
  let app = @crescent.new()
  app.resource(
    "/items",
    {
      list: Some(_ => @crescent.HttpResponse::ok().json_value(items)),
      get: Some(event => {
        let id = event.require_param_int("id")
        for item in items {
          if item.id == id {
            return @crescent.HttpResponse::ok().json_value(item)
          }
        }
        raise @crescent.HttpError::HttpError(@crescent.NotFound, "not found")
      }),
      create: Some(event => {
        let input : CreateItemInput = event.json()
        let item = Item::{ id: 2, name: input.name }
        items.push(item)
        @crescent.HttpResponse::created().json_value(item)
      }),
      update: None,
      delete: None,
    },
  )
  let client = @crescent.TestClient::new(app)

  // List
  let res = client.get("/items")
  assert_eq(res.status, @crescent.OK)
  let list : Array[Item] = res.body_json()
  assert_eq(list.length(), 1)

  // Create
  let res2 = client.post("/items", body=b"{\"name\":\"Beta\"}")
  assert_eq(res2.status, @crescent.Created)
  let created : Item = res2.body_json()
  assert_eq(created.name, "Beta")

  // Get by ID
  let res3 = client.get("/items/1")
  assert_eq(res3.status, @crescent.OK)
  let item : Item = res3.body_json()
  assert_eq(item, { id: 1, name: "Alpha" })

  // Not found
  let res4 = client.get("/items/999")
  assert_eq(res4.status, @crescent.NotFound)
}
```

## Cookies

```mbt
test "set and format cookie" {
  let res = @crescent.HttpResponse::new(@crescent.OK)
  res.set_cookie(
    "session",
    "abc123",
    max_age=3600,
    http_only=true,
    same_site=@crescent.Lax,
  )
  assert_true(res.cookies.get("session") is Some(_))
}
```

## Redirects

```mbt
test "redirect helpers" {
  let r301 = @crescent.HttpResponse::redirect("/new")
  assert_eq(r301.status_code, @crescent.MovedPermanently)
  assert_eq(r301.headers.get("Location"), Some("/new"))

  let r302 = @crescent.HttpResponse::redirect_temporary("/temp")
  assert_eq(r302.status_code, @crescent.Found)
}
```
