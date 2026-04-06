///|
fn handle_not_found() -> HttpHandler {
  (_ : MocketEvent) => HttpResponse(NotFound).body("Not Found")
}
