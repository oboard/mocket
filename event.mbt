///|
pub(all) struct MocketEvent {
  req : HttpRequest
  res : HttpResponse
  params : Map[String, StringView]
}

///|
pub fn[T : BodyReader] MocketEvent::body(self : MocketEvent) -> T raise {
  self.req.body()
}
