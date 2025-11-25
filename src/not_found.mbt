///|
pub async fn handle_not_found(_ : MocketEvent) -> &Responder noraise {
  HttpResponse::new(404).body("Not Found")
}
