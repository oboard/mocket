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
  Some(@mocket.StaticAssetMeta::new(path=self.path + "/" + id))
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_contents(
  self,
  id : String,
) -> &Responder {
  let res : &Responder = @mocket.HttpResponse::new(@mocket.OK).body(
    @fs.read_file_to_bytes(self.path + "/" + id),
  ) catch {
    _ => @mocket.HttpResponse::new(@mocket.NotFound).body("Not Found")
  }
  res
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_type(_, _ : String) -> String? {
  None
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_encodings(_) -> Map[
  String,
  String,
] {
  {}
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_index_names(_) -> Array[
  String,
] {
  [
    "index.html", "index.htm", "index.txt", "index.md", "index.json", "index.xml",
    "index.xhtml", "default.html", "default.htm", "home.html", "home.htm",
  ]
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_fallthrough(_) -> Bool {
  false
}
