///|
pub(all) struct MocketEvent {
  req : HttpRequest
  res : HttpResponse
  params : Map[String, StringView]
}

///|
pub async fn[T : BodyReader] MocketEvent::body(self : MocketEvent) -> T {
  self.req.body()
}
