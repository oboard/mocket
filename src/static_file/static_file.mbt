// ///|

///|
using @mocket {trait ServeStaticProvider, trait Responder}

///|
pub struct StaticFileProvider {
  path : String
}

///|
pub fn new(path : String) -> StaticFileProvider {
  { path, }
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_meta(
  self,
  id : String,
) -> @mocket.StaticAssetMeta? {
  None
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_contents(
  self,
  id : String,
) -> &Responder {
  let res : &Responder = @mocket.HttpResponse::new(@mocket.OK).body(
    @fs.read_file_to_bytes(self.path + "/" + id),
  ) catch {
    _ => @mocket.HttpResponse::new(@mocket.NotFound)
  }
  res
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_type(
  self,
  ext : String,
) -> String? {
  None
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_encodings(self) -> Map[
  String,
  String,
] {
  {}
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_index_names(self) -> Array[
  String,
] {
  []
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_fallthrough(self) -> Bool {
  false
}
