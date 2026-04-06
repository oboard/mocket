///|
/// Creates a 200 OK response.
pub fn HttpResponse::ok() -> HttpResponse {
  HttpResponse(OK)
}

///|
/// Creates a 201 Created response.
pub fn HttpResponse::created() -> HttpResponse {
  HttpResponse(Created)
}

///|
/// Creates a 204 No Content response.
pub fn HttpResponse::no_content() -> HttpResponse {
  HttpResponse(NoContent)
}

///|
/// Creates a 400 Bad Request response.
pub fn HttpResponse::bad_request() -> HttpResponse {
  HttpResponse(BadRequest)
}

///|
/// Creates a 401 Unauthorized response.
pub fn HttpResponse::unauthorized() -> HttpResponse {
  HttpResponse(Unauthorized)
}

///|
/// Creates a 403 Forbidden response.
pub fn HttpResponse::forbidden() -> HttpResponse {
  HttpResponse(Forbidden)
}

///|
/// Creates a 404 Not Found response.
pub fn HttpResponse::not_found() -> HttpResponse {
  HttpResponse(NotFound)
}

///|
/// Creates a 500 Internal Server Error response.
pub fn HttpResponse::internal_server_error() -> HttpResponse {
  HttpResponse(InternalServerError)
}

///|
/// Creates an error response with a JSON body containing status and message.
pub fn HttpResponse::error(
  status : StatusCode,
  message : String,
) -> HttpResponse {
  let res = HttpResponse(status)
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
