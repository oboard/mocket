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
fn static_asset_etag(
  mtime_sec : Int64,
  mtime_nsec : Int,
  size : Int64,
) -> String {
  "\"\{mtime_sec}-\{mtime_nsec}-\{size}\""
}

///|
async fn open_static_asset(path : String) -> @fs.File? noraise {
  try @fs.open(path, mode=ReadOnly) catch {
    _ => None
  } noraise {
    file =>
      if file.kind() is Regular {
        Some(file)
      } else {
        file.close()
        None
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
      match open_static_asset(path) {
        Some(file) => {
          defer file.close()
          match (try? file.size(), try? file.mtime()) {
            (Ok(size), Ok((mtime_sec, mtime_nsec))) =>
              Some(
                @mocket.StaticAssetMeta::new(
                  etag=static_asset_etag(mtime_sec, mtime_nsec, size),
                  mtime=mtime_sec,
                  path~,
                  size~,
                ),
              )
            _ => None
          }
        }
        None => None
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
    Some(path) =>
      match open_static_asset(path) {
        Some(file) => {
          defer file.close()
          let headers = match (try? file.size(), try? file.mtime()) {
            (Ok(size), Ok((mtime_sec, mtime_nsec))) => {
              let headers : Map[String, String] = {}
              headers.set("Content-Length", size.to_string())
              headers.set(
                "ETag",
                static_asset_etag(mtime_sec, mtime_nsec, size),
              )
              headers
            }
            _ => {}
          }
          try file.read_all().binary() catch {
            _ => @mocket.HttpResponse::new(NotFound).body("Not Found")
          } noraise {
            contents => @mocket.HttpResponse::new(OK, headers~).body(contents)
          }
        }
        None => @mocket.HttpResponse::new(NotFound).body("Not Found")
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
