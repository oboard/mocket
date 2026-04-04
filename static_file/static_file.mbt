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
fn is_safe_static_id(id : String) -> Bool {
  if id.find("\\") is Some(_) {
    return false
  }
  for segment in id.split("/") {
    if segment == ".." {
      return false
    }
  }
  true
}

///|
fn StaticFileProvider::full_path(
  self : StaticFileProvider,
  id : String,
) -> String? {
  if is_safe_static_id(id) {
    Some(self.path + "/" + id)
  } else {
    None
  }
}

///|
fn is_static_asset_file(path : String) -> Bool {
  if !@fs.path_exists(path) {
    false
  } else {
    @fs.is_file(path) catch {
      _ => false
    }
  }
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_meta(
  self,
  id : String,
) -> @mocket.StaticAssetMeta? {
  match self.full_path(id) {
    Some(path) =>
      if is_static_asset_file(path) {
        Some(@mocket.StaticAssetMeta::new(path~))
      } else {
        None
      }
    None => None
  }
}

///|
pub impl ServeStaticProvider for StaticFileProvider with get_contents(
  self,
  id : String,
) -> &Responder {
  match self.full_path(id) {
    Some(path) => {
      let res : &Responder = @mocket.HttpResponse::new(OK).body(
        @fs.read_file_to_bytes(path),
      ) catch {
        _ => @mocket.HttpResponse::new(NotFound).body("Not Found")
      }
      res
    }
    None => @mocket.HttpResponse::new(NotFound).body("Not Found")
  }
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
