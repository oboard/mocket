// Full-stack test cases demonstrating the AI-friendly API pattern.
//
// These tests show the complete flow an AI agent would use:
// 1. Define shared types with derive(ToJson, FromJson)
// 2. Build handlers using typed parsing and serialization
// 3. Test with TestClient (no network)
// 4. Verify the JSON contract round-trips correctly
// 5. Use event.json() shorthand and require_param helpers

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
fn build_todo_app() -> @crescent.Mocket {
  let app = @crescent.new()
  // In-memory store
  let todos : Array[Todo] = [
    { id: 1, title: "Learn MoonBit", done: true },
    { id: 2, title: "Build web app", done: false },
  ]
  let next_id = Ref::new(3)

  // List todos
  app.get_raw("/api/todos", fn(_) noraise {
    @crescent.HttpResponse::ok().json_value(todos)
  })

  // Get single todo by ID
  app.get("/api/todos/:id", event => {
    let id = match event.param_int("id") {
      Some(id) => id
      None =>
        raise @crescent.HttpError::HttpError(
          @crescent.BadRequest,
          "invalid todo id",
        )
    }
    for todo in todos {
      if todo.id == id {
        return @crescent.HttpResponse::ok().json_value(todo)
      }
    }
    raise @crescent.HttpError::HttpError(
      @crescent.NotFound,
      "todo \{id} not found",
    )
  })

  // Create todo
  app.post("/api/todos", event => {
    let input : CreateTodo = event.req.json()
    let id = next_id.val
    next_id.val += 1
    let todo = Todo::{ id, title: input.title, done: false }
    todos.push(todo)
    @crescent.HttpResponse::created().json_value(todo)
  })

  // Health check
  app.get_raw("/health", fn(_) noraise { "ok" })

  // Apply security headers
  app.use_middleware(@crescent.security_headers())

  app
}

// ---- Tests (what AI agents verify) ----

///|
async test "full-stack: list todos returns json array" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/api/todos")
  assert_eq(res.status, @crescent.OK)
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
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/1")
  assert_eq(res.status, @crescent.OK)
  let todo : Todo = res.body_json()
  assert_eq(todo, { id: 1, title: "Learn MoonBit", done: true })
}

///|
async test "full-stack: get todo with invalid id returns 400" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/abc")
  assert_eq(res.status, @crescent.BadRequest)
  let wrapper : ApiErrorWrapper = res.body_json()
  let err = wrapper.error
  assert_eq(err.status, 400)
  assert_true(err.message.contains("invalid todo id"))
}

///|
async test "full-stack: get nonexistent todo returns 404" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/api/todos/999")
  assert_eq(res.status, @crescent.NotFound)
  let wrapper : ApiErrorWrapper = res.body_json()
  let err = wrapper.error
  assert_eq(err.status, 404)
  assert_true(err.message.contains("not found"))
}

///|
async test "full-stack: create todo with json body" {
  let client = @crescent.TestClient::new(build_todo_app())
  let input : CreateTodo = { title: "Write tests" }
  let body = input.to_json().stringify()
  let res = client.post("/api/todos", body=@utf8.encode(body))
  assert_eq(res.status, @crescent.Created)
  let todo : Todo = res.body_json()
  assert_eq(todo.title, "Write tests")
  assert_eq(todo.done, false)
  assert_eq(todo.id, 3) // auto-incremented
}

///|
async test "full-stack: create todo with invalid json returns 400" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.post("/api/todos", body=b"not json")
  assert_eq(res.status, @crescent.BadRequest)
}

///|
async test "full-stack: create todo with wrong schema returns 400" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.post("/api/todos", body=b"{\"wrong_field\":123}")
  assert_eq(res.status, @crescent.BadRequest)
}

///|
async test "full-stack: security headers applied to all responses" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/api/todos")
  assert_eq(res.headers.get("X-Content-Type-Options"), Some("nosniff"))
  assert_eq(res.headers.get("X-Frame-Options"), Some("DENY"))
}

///|
async test "full-stack: health check is plain text" {
  let client = @crescent.TestClient::new(build_todo_app())
  let res = client.get("/health")
  assert_eq(res.status, @crescent.OK)
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
  let res = @crescent.HttpResponse::ok().json_value(profile)
  let json_text = @utf8.decode(res.raw_body) catch { _ => "" }

  // Deserialize from JSON (frontend → backend)
  let req = @crescent.HttpRequest::new_request(
    @crescent.Post,
    "/",
    {},
    @utf8.encode(json_text),
  )
  let parsed : UserProfile = req.json()
  assert_eq(parsed, profile)
}

///|
async test "full-stack: nested json with optional fields" {
  let app = @crescent.new()
  app.post("/api/profile", event => {
    let profile : UserProfile = event.req.json()
    // Echo back with modification
    @crescent.HttpResponse::ok().json_value({
      ..profile,
      tags: profile.tags..push("verified"),
    })
  })
  let client = @crescent.TestClient::new(app)
  let profile : UserProfile = {
    id: 1,
    name: "Bob",
    email: "bob@test.com",
    tags: ["user"],
  }
  let body = @utf8.encode(profile.to_json().stringify())
  let res = client.post("/api/profile", body~)
  assert_eq(res.status, @crescent.OK)
  let result : UserProfile = res.body_json()
  assert_eq(result.name, "Bob")
  assert_eq(result.tags, ["user", "verified"])
}

///|
async test "full-stack: middleware chain with typed handlers" {
  let log : Array[String] = []
  let app = @crescent.new()
  // Logging middleware
  app.use_middleware((event, next) => {
    log.push("before: \{event.req.http_method} \{event.req.url}")
    let res = next()
    log.push("after")
    res
  })
  app.get("/api/data", _event => {
    let todo : Todo = { id: 1, title: "test", done: false }
    @crescent.HttpResponse::ok().json_value(todo)
  })
  let client = @crescent.TestClient::new(app)
  let res = client.get("/api/data")
  assert_eq(res.status, @crescent.OK)
  let todo : Todo = res.body_json()
  assert_eq(todo.id, 1)
  assert_eq(log[0], "before: GET /api/data")
  assert_eq(log[1], "after")
}

///|
async test "full-stack: event.json() shorthand parses request body" {
  let app = @crescent.new()
  app.post("/api/todos", event => {
    // Use event.json() shorthand instead of event.req.json()
    let input : CreateTodo = event.json()
    let todo = Todo::{ id: 1, title: input.title, done: false }
    @crescent.HttpResponse::created().json_value(todo)
  })
  let client = @crescent.TestClient::new(app)
  let body = @utf8.encode(
    ({ title: "Test shorthand" } : CreateTodo).to_json().stringify(),
  )
  let res = client.post("/api/todos", body~)
  assert_eq(res.status, @crescent.Created)
  let todo : Todo = res.body_json()
  assert_eq(todo.title, "Test shorthand")
}

///|
async test "full-stack: require_param_int simplifies typed handlers" {
  let app = @crescent.new()
  app.get("/api/todos/:id", event => {
    // Use require_param_int instead of match + raise boilerplate
    let id = event.require_param_int("id")
    let todo = Todo::{ id, title: "Found", done: true }
    @crescent.HttpResponse::ok().json_value(todo)
  })
  let client = @crescent.TestClient::new(app)
  // Valid ID
  let res = client.get("/api/todos/42")
  assert_eq(res.status, @crescent.OK)
  let todo : Todo = res.body_json()
  assert_eq(todo.id, 42)
  // Invalid ID returns 400
  let res2 = client.get("/api/todos/abc")
  assert_eq(res2.status, @crescent.BadRequest)
}

///|
async test "full-stack: require_param for string params" {
  let app = @crescent.new()
  app.get("/api/users/:name/profile", event => {
    let name = event.require_param("name")
    @crescent.HttpResponse::ok().json_value(UserProfile::{
      id: 1,
      name,
      email: "\{name}@test.com",
      tags: [],
    })
  })
  let client = @crescent.TestClient::new(app)
  let res = client.get("/api/users/alice/profile")
  assert_eq(res.status, @crescent.OK)
  let profile : UserProfile = res.body_json()
  assert_eq(profile.name, "alice")
  assert_eq(profile.email, "alice@test.com")
}
