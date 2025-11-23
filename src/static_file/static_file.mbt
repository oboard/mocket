// // ///|

// ///|
// using @mocket {trait ServeStaticProvider, trait Responder}

// ///|
// pub struct StaticFileProvider {
//   path : String
// }

// ///|
// pub fn StaticFileProvider::new(path : String) -> StaticFileProvider {
//   { path, }
// }

// ///|
// pub impl ServeStaticProvider for StaticFileProvider with get_meta(
//   self,
//   id : String,
// ) -> StaticAssetMeta? {
//   None
// }

// ///|
// pub impl ServeStaticProvider for StaticFileProvider with get_contents(
//   self,
//   id : String,
// ) -> &Responder {
//   let res : &Responder = @mocket.bytes(
//     @fs.read_file_to_bytes(self.path + "/" + id),
//   ) catch {
//     _ => @mocket.HttpResponse::not_found()
//   }
//   res
// }
// // Custom MIME type resolver function

// // ///|
// // impl ServeStaticProvider for StaticFileProvider with get_type(
// //   self,
// //   ext : String,
// // ) -> String? {

// // }
// // // Encodings map

// // ///|
// // impl ServeStaticProvider for StaticFileProvider with get_encodings(self) -> Map[
// //   String,
// //   String,
// // ] {

// // }
// // // Index names

// // ///|
// // impl ServeStaticProvider for StaticFileProvider with get_index_names(self) -> Array[
// //   String,
// // ] {

// // }
// // // Fallthrough

// // ///|
// // impl ServeStaticProvider for StaticFileProvider with get_fallthrough(self) -> Bool {

// // }
