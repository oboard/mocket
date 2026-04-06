// Full-stack test cases demonstrating the AI-friendly API pattern.
//
// These tests show the complete flow an AI agent would use:
// 1. Define shared types with derive(ToJson, FromJson)
// 2. Build handlers using typed parsing and serialization
// 3. Test with TestClient (no network)
// 4. Verify the JSON contract round-trips correctly

// ---- Shared types (would be in a shared package for frontend+backend) ----

///|
struct Todo {
  id : Int
  title : String
  done : Bool
} derive(ToJson, FromJson, Eq)

///|
impl Show for Todo with output(self, logger) {
  logger.write_string("Todo { id: ")
  logger.write_object(self.id)
  logger.write_string(", title: ")
  logger.write_object(self.title)
  logger.write_string(", done: ")
  logger.write_object(self.done)
  logger.write_string(" }")
}

///|
struct CreateTodo {
  title : String
} derive(ToJson, FromJson)

///|
struct UserProfile {
  id : Int
  name : String
  email : String
  tags : Array[String]
} derive(ToJson, FromJson, Eq)

///|
impl Show for UserProfile with output(self, logger) {
  logger.write_string("UserProfile { id: ")
  logger.write_object(self.id)
  logger.write_string(", name: ")
  logger.write_object(self.name)
  logger.write_string(" }")
}

///|
struct ApiErrorWrapper {
  error : ApiErrorDetail
} derive(FromJson)

///|
struct ApiErrorDetail {
  status : Int
  message : String
} derive(FromJson)

// ---- Build an app (what AI agents write) ----

///|
fn build_todo_app() -> @mocket.Mocket {
  let app = @mocket.new()
  // In-memory store
  let todos : Array[Todo] = [
    { id: 1, title: "Learn MoonBit", done: true },
    { id: 2, title: "Build web app", done: false },
  ]
  let next_id = Ref::new(3)

  // List todos
  app.get("/api/todos", fn(_) noraise {
    @mocket.HttpResponse::ok().json_value(todos)
  })

  // Get single todo by ID
  app.get_json("/api/todos/:id", event => {
    let id = match event.param_int("id") {
      Some(id) => id
      None =>
        raise @mocket.HttpError::HttpError(
          @mocket.BadRequest,
          "invalid todo id",
        )
    }
    for todo in todos {
      if todo.id == id {
        return @mocket.HttpResponse::ok().json_value(todo)
      }
    }
    raise @mocket.HttpError::HttpError(@mocket.NotFound, "todo \{id} not found")
  })

  // Create todo
  app.post_json("/api/todos", event => {
    let input : CreateTodo = event.req.json()
    let id = next_id.val
    next_id.val += 1
    let todo = Todo::{ id, title: input.title, done: false }
    todos.push(todo)
    @mocket.HttpResponse::created().json_value(todo)
  })

  // Health check
  app.get("/health", fn(_) noraise { "ok" })

  // Apply security headers
  app.use_middleware(@mocket.security_headers())

  app
}

// ---- Tests (what AI agents verify) ----

///|
async test "full-stack: list todos returns json array" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/api/todos")
  assert_eq(res.status, @mocket.OK)
  inspect(
    res.headers.get("Content-Type"),
    content="Some(\"application/json; charset=utf-8\")",
  )
  let todos : Array[Todo] = res.body_json()
  assert_eq(todos.length(), 2)
  assert_eq(todos[0].title, "Learn MoonBit")
  assert_eq(todos[1].done, false)
}

///|
async test "full-stack: get single todo by id" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/1")
  assert_eq(res.status, @mocket.OK)
  let todo : Todo = res.body_json()
  assert_eq(todo, { id: 1, title: "Learn MoonBit", done: true })
}

///|
async test "full-stack: get todo with invalid id returns 400" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/abc")
  assert_eq(res.status, @mocket.BadRequest)
  let wrapper : ApiErrorWrapper = res.body_json()
  let err = wrapper.error
  assert_eq(err.status, 400)
  assert_true(err.message.contains("invalid todo id"))
}

///|
async test "full-stack: get nonexistent todo returns 404" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/999")
  assert_eq(res.status, @mocket.NotFound)
  let wrapper : ApiErrorWrapper = res.body_json()
  let err = wrapper.error
  assert_eq(err.status, 404)
  assert_true(err.message.contains("not found"))
}

///|
async test "full-stack: create todo with json body" {
  let client = @mocket.TestClient::new(build_todo_app())
  let input : CreateTodo = { title: "Write tests" }
  let body = input.to_json().stringify()
  let res = client.post("/api/todos", body=@utf8.encode(body))
  assert_eq(res.status, @mocket.Created)
  let todo : Todo = res.body_json()
  assert_eq(todo.title, "Write tests")
  assert_eq(todo.done, false)
  assert_eq(todo.id, 3) // auto-incremented
}

///|
async test "full-stack: create todo with invalid json returns 400" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.post("/api/todos", body=b"not json")
  assert_eq(res.status, @mocket.BadRequest)
}

///|
async test "full-stack: create todo with wrong schema returns 400" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.post("/api/todos", body=b"{\"wrong_field\":123}")
  assert_eq(res.status, @mocket.BadRequest)
}

///|
async test "full-stack: security headers applied to all responses" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/api/todos")
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
  assert_eq(res.headers.get("X-Frame-Options"), Some("DENY"))
}

///|
async test "full-stack: health check is plain text" {
  let client = @mocket.TestClient::new(build_todo_app())
  let res = client.get("/health")
  assert_eq(res.status, @mocket.OK)
  assert_eq(res.body_text(), "ok")
}

///|
async test "full-stack: json round-trip preserves all fields" {
  let profile = UserProfile::{
    id: 42,
    name: "Alice",
    email: "alice@example.com",
    tags: ["admin", "active"],
  }
  // Serialize to JSON (backend → frontend)
  let res = @mocket.HttpResponse::ok().json_value(profile)
  let json_text = @utf8.decode(res.raw_body) catch { _ => "" }

  // Deserialize from JSON (frontend → backend)
  let req : @mocket.HttpRequest = {
    http_method: "POST",
    url: "/",
    headers: {},
    raw_body: @utf8.encode(json_text),
  }
  let parsed : UserProfile = req.json()
  assert_eq(parsed, profile)
}

///|
async test "full-stack: nested json with optional fields" {
  let app = @mocket.new()
  app.post_json("/api/profile", event => {
    let profile : UserProfile = event.req.json()
    // Echo back with modification
    @mocket.HttpResponse::ok().json_value({
      ..profile,
      tags: profile.tags..push("verified"),
    })
  })
  let client = @mocket.TestClient::new(app)
  let profile : UserProfile = {
    id: 1,
    name: "Bob",
    email: "bob@test.com",
    tags: ["user"],
  }
  let body = @utf8.encode(profile.to_json().stringify())
  let res = client.post("/api/profile", body~)
  assert_eq(res.status, @mocket.OK)
  let result : UserProfile = res.body_json()
  assert_eq(result.name, "Bob")
  assert_eq(result.tags, ["user", "verified"])
}

///|
async test "full-stack: middleware chain with typed handlers" {
  let log : Array[String] = []
  let app = @mocket.new()
  // Logging middleware
  app.use_middleware((event, next) => {
    log.push("before: \{event.req.http_method} \{event.req.url}")
    let res = next()
    log.push("after")
    res
  })
  app.get_json("/api/data", _event => {
    let todo : Todo = { id: 1, title: "test", done: false }
    @mocket.HttpResponse::ok().json_value(todo)
  })
  let client = @mocket.TestClient::new(app)
  let res = client.get("/api/data")
  assert_eq(res.status, @mocket.OK)
  let todo : Todo = res.body_json()
  assert_eq(todo.id, 1)
  assert_eq(log[0], "before: GET /api/data")
  assert_eq(log[1], "after")
}
