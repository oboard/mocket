///|
pub struct HttpEvent {
  req : HttpRequest
  res : HttpResponse
  mut params : Map[String, String]
}
