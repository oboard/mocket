///|
pub async fn handle_not_found(_ : MocketEvent) -> &Responder noraise {
  HttpResponse::new(NotFound).body("Not Found")
}
