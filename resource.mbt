///|
/// Configuration for registering a RESTful resource with standard CRUD routes.
pub struct ResourceConfig {
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
/// Creates a new `ResourceConfig` with optional CRUD handlers.
pub fn ResourceConfig::new(
  list? : async (MocketEvent) -> &Responder,
  get? : async (MocketEvent) -> &Responder,
  create? : async (MocketEvent) -> &Responder,
  update? : async (MocketEvent) -> &Responder,
  delete? : async (MocketEvent) -> &Responder,
) -> ResourceConfig {
  { list, get, create, update, delete }
}

///|
/// Registers standard REST routes (list, get, create, update, delete) for a resource path.
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
