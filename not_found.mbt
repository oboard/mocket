///|
pub fn handle_not_found() -> HttpHandler {
  (_ : MocketEvent) => HttpResponse::new(NotFound).body("Not Found")
}
