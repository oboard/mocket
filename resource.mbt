/// Configuration for registering a RESTful resource with standard CRUD routes.
///
/// Each field is optional — only provided handlers are registered.
/// All handlers use the raising API (automatic error mapping).
///
/// Example:
/// ```
/// app.resource("/api/todos", ResourceConfig::{
///   list:   Some(event => HttpResponse::ok().json_value(todos)),
///   get:    Some(event => {
///     let id = event.require_param_int("id")
///     HttpResponse::ok().json_value(find_todo(id))
///   }),
///   create: Some(event => {
///     let input : CreateTodo = event.json()
///     HttpResponse::created().json_value(save_todo(input))
///   }),
///   update: Some(event => {
///     let id = event.require_param_int("id")
///     let input : UpdateTodo = event.json()
///     HttpResponse::ok().json_value(update_todo(id, input))
///   }),
///   delete: Some(event => {
///     let id = event.require_param_int("id")
///     delete_todo(id)
///     HttpResponse::no_content()
///   }),
/// })
/// // Registers:
/// //   GET    /api/todos        -> list
/// //   GET    /api/todos/:id    -> get
/// //   POST   /api/todos        -> create
/// //   PUT    /api/todos/:id    -> update
/// //   DELETE /api/todos/:id    -> delete
/// ```

///|
pub(all) struct ResourceConfig {
  /// GET /path — list all resources
  list : (async (MocketEvent) -> &Responder)?
  /// GET /path/:id — get a single resource by ID
  get : (async (MocketEvent) -> &Responder)?
  /// POST /path — create a new resource
  create : (async (MocketEvent) -> &Responder)?
  /// PUT /path/:id — update an existing resource
  update : (async (MocketEvent) -> &Responder)?
  /// DELETE /path/:id — delete a resource
  delete : (async (MocketEvent) -> &Responder)?

  fn new(
    list? : async (MocketEvent) -> &Responder,
    get? : async (MocketEvent) -> &Responder,
    create? : async (MocketEvent) -> &Responder,
    update? : async (MocketEvent) -> &Responder,
    delete? : async (MocketEvent) -> &Responder,
  ) -> ResourceConfig
}

///|
pub fn ResourceConfig::new(
  list? : async (MocketEvent) -> &Responder,
  get? : async (MocketEvent) -> &Responder,
  create? : async (MocketEvent) -> &Responder,
  update? : async (MocketEvent) -> &Responder,
  delete? : async (MocketEvent) -> &Responder,
) -> ResourceConfig {
  { list, get, create, update, delete }
}

/// Registers standard REST routes for a resource.
/// This is the recommended way for AI agents to set up CRUD APIs — one call
/// registers all standard endpoints with correct HTTP methods and paths.
///
/// Given a base path like `/api/todos`, this registers:
/// - `GET /api/todos` → list handler
/// - `GET /api/todos/:id` → get handler
/// - `POST /api/todos` → create handler
/// - `PUT /api/todos/:id` → update handler
/// - `DELETE /api/todos/:id` → delete handler

///|
pub fn Mocket::resource(
  self : Mocket,
  path : String,
  config : ResourceConfig,
) -> Unit {
  match config.list {
    Some(handler) => self.get(path, handler)
    None => ()
  }
  match config.get {
    Some(handler) => self.get(path + "/:id", handler)
    None => ()
  }
  match config.create {
    Some(handler) => self.post(path, handler)
    None => ()
  }
  match config.update {
    Some(handler) => self.put(path + "/:id", handler)
    None => ()
  }
  match config.delete {
    Some(handler) => self.delete(path + "/:id", handler)
    None => ()
  }
}
