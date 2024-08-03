pub struct HeavenBinding {
  mut listen : (String, (@json.JsonValue) -> Unit) -> Unit
  mut send : (String, @json.JsonValue) -> Unit
}

pub struct HttpResponse {
  id : Double
}

pub struct HttpRequest {
  url : String?
  path : String?
  query : Map[String, String]
  body : @json.JsonValue?
}

pub struct HttpServer {
  port : Double
  mappings : Map[String, (HttpRequest, HttpResponse) -> @json.JsonValue]
}

let binding : HeavenBinding = {
  listen: fn(_a, _b) { println("Please bind heaven.") },
  send: fn(_a, _b) { println("Please bind heaven.") },
}

pub fn html(data : String) -> @json.JsonValue {
  { "type": "html", "data": String(data) }
}

pub fn file(path : String) -> @json.JsonValue {
  { "type": "file", "path": String(path) }
}

pub fn listen(
  context : (
    (String, (@json.JsonValue) -> Unit) -> Unit,
    (String, @json.JsonValue) -> Unit,
  ),
  port : Double
) -> HttpServer {
  binding.listen = context.0
  binding.send = context.1
  let server = { port, mappings: of([]) }
  (binding.listen)(
    "http.request",
    fn(result) {
      match result {
        [req, res] =>
          match (req, res) {
            (
              { "method": String(method), "url": String(url) },
              { "id": Number(id) },
            ) => {
              let urlObject = URL::parse(url)
              let request : HttpRequest = {
                url: Some(url),
                path: Some(urlObject.path),
                query: urlObject.query.or({  }),
                body: match req {
                  { "body": body } => Some(body)
                  _ => None
                },
              }
              let response : HttpResponse = { id, }
              fn doHandler(
                reqFn : ((HttpRequest, HttpResponse) -> @json.JsonValue)?
              ) {
                match reqFn {
                  Some(handler) => {
                    let result = handler(request, response)
                    match result {
                      Object({ "type": "html", "data": data }) => {
                        response.writeHead(200, { "Content-Type": "text/html" })
                        response.end(data)
                      }
                      Object({ "type": "file", "path": String(path) }) => {
                        let mime = @mimetype.new()
                        let mimeType = mime.getType(path)
                        response.writeHead(
                          200,
                          {
                            "Content-Type": mimeType.or(
                              "application/octet-stream",
                            )
                            |> String,
                          },
                        )
                        response.end(result)
                      }
                      Object(_) => {
                        response.writeHead(
                          200,
                          { "Content-Type": "application/json" },
                        )
                        response.end(result)
                      }
                      String(_) => {
                        response.writeHead(
                          200,
                          { "Content-Type": "text/plain" },
                        )
                        response.end(result)
                      }
                      _ => {
                        response.writeHead(
                          200,
                          { "Content-Type": "text/plain" },
                        )
                        response.end(result)
                      }
                    }
                  }
                  None => {
                    response.writeHead(404, { "Content-Type": "text/plain" })
                    response.end("Not Found")
                  }
                }
              }

              let reqHead = method + " " + urlObject.path
              println(reqHead)
              // doHandler(server.mappings.get(method + " " + urlObject.path))
              // doHandler(server.mappings.get("ALL " + urlObject.path))
              doHandler(
                if server.mappings.contains(reqHead) {
                  server.mappings.get(reqHead)
                } else {
                  server.mappings.get("ALL " + urlObject.path)
                },
              )
            }
            _ => println("Invalid struct")
          }
        _ => println("Invalid request")
      }
    },
  )
  (binding.send)("http.createServer", {  })
  (binding.send)("http.listen", Number(server.port))
  server
}

pub fn get(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["GET " + mapping] = handler
}

pub fn post(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["POST " + mapping] = handler
}

pub fn put(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["PUT " + mapping] = handler
}

pub fn delete(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["DELETE " + mapping] = handler
}

pub fn patch(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["PATCH " + mapping] = handler
}

pub fn options(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["OPTIONS " + mapping] = handler
}

pub fn head(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["HEAD " + mapping] = handler
}

pub fn trace(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["TRACE " + mapping] = handler
}

pub fn connect(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["CONNECT " + mapping] = handler
}

pub fn all(
  self : HttpServer,
  mapping : String,
  handler : (HttpRequest, HttpResponse) -> @json.JsonValue
) -> Unit {
  self.mappings["ALL " + mapping] = handler
}

pub fn writeHead(
  self : HttpResponse,
  statusCode : @json.JsonValue,
  headers : @json.JsonValue
) -> Unit {
  (binding.send)("http.writeHead", [Number(self.id), statusCode, headers])
}

pub fn end(self : HttpResponse, data : @json.JsonValue) -> Unit {
  (binding.send)("http.end", [Number(self.id), data])
}
