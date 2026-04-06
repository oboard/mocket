///|
/// Creates a 200 OK response.
pub fn HttpResponse::ok() -> HttpResponse {
  HttpResponse::new(OK)
}

///|
/// Creates a 201 Created response.
pub fn HttpResponse::created() -> HttpResponse {
  HttpResponse::new(Created)
}

///|
/// Creates a 204 No Content response.
pub fn HttpResponse::no_content() -> HttpResponse {
  HttpResponse::new(NoContent)
}

///|
/// Creates a 400 Bad Request response.
pub fn HttpResponse::bad_request() -> HttpResponse {
  HttpResponse::new(BadRequest)
}

///|
/// Creates a 401 Unauthorized response.
pub fn HttpResponse::unauthorized() -> HttpResponse {
  HttpResponse::new(Unauthorized)
}

///|
/// Creates a 403 Forbidden response.
pub fn HttpResponse::forbidden() -> HttpResponse {
  HttpResponse::new(Forbidden)
}

///|
/// Creates a 404 Not Found response.
pub fn HttpResponse::not_found() -> HttpResponse {
  HttpResponse::new(NotFound)
}

///|
/// Creates a 500 Internal Server Error response.
pub fn HttpResponse::internal_server_error() -> HttpResponse {
  HttpResponse::new(InternalServerError)
}

///|
/// Creates an error response with a JSON body containing status and message.
pub fn HttpResponse::error(
  status : StatusCode,
  message : String,
) -> HttpResponse {
  let res = HttpResponse::new(status)
  let json : Json = {
    "error": {
      "status": status.to_int().to_json(),
      "message": message.to_json(),
    },
  }
  res.headers.set("Content-Type", "application/json; charset=utf-8")
  res.raw_body = @utf8.encode(json.stringify())
  res
}
