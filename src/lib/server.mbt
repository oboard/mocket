///|
fn run_async(f : () -> Unit!Async) -> Unit = "%async.run"

///|
// async fn suspend[T, E : Error](f : ((T) -> Unit, (E) -> Unit) -> Unit) -> T!E = "%async.suspend"

///|
pub(all) struct HttpServer {
  port : Int
  mappings : Map[String, (@http.HttpRequest, @http.HttpResponse) -> Json!Async]
}

///|
pub fn html(data : String) -> Json {
  { "_T": "html", "data": data.to_json() }
}

///|
pub fn file(path : String) -> Json {
  { "_T": "file", "path": path.to_json() }
}

///|
pub fn buffer(data : Bytes) -> Json {
  {
    "_T": "buffer",
    "data": data
    .to_array()
    .map(fn(n : Byte) -> Json { n.to_int().to_json() })
    .to_json(),
  }
}

///|
pub fn listen(port : Int) -> HttpServer!Error {
  let server = { port, mappings: {} }
  @http.request!(fn(request, response) {
    fn doHandler(
      reqFn : ((@http.HttpRequest, @http.HttpResponse) -> Json!Async)?
    ) -> Unit {
      match reqFn {
        Some(handler) =>
          run_async(fn() {
            let result = handler!(request, response)
            match result {
              Object({ "_T": "html", "data": data, .. }) => {
                response.writeHead(200, { "Content-Type": "text/html" })
                response.end(data)
              }
              Object({ "_T": "file", "path": String(path), .. }) => {
                let mime = @mimetype.T::new()
                let mimeType = mime.get_type(path)
                response.writeHead(200, {
                  "Content-Type": mimeType
                  .or("application/octet-stream")
                  .to_json(),
                })
                response.end(result)
              }
              Object(_) => {
                response.writeHead(200, { "Content-Type": "application/json" })
                response.end(result)
              }
              String(_) => {
                response.writeHead(200, { "Content-Type": "text/plain" })
                response.end(result)
              }
              _ => {
                response.writeHead(200, { "Content-Type": "text/plain" })
                response.end(result)
              }
            }
          })
        None => {
          response.writeHead(404, { "Content-Type": "text/plain" })
          response.end("Not Found")
        }
      }
    }

    let reqHead = "\{request.method} \{request.path}"
    let reqHeadAll = "ALL " + request.path
    let reqHeadAllMethod = "\{request.method} *"
    println(@chalk.chalk().color(@chalk.Green).render(reqHead))
    doHandler(
      if server.mappings.contains(reqHead) {
        server.mappings.get(reqHead)
      } else if server.mappings.contains(reqHeadAll) {
        server.mappings.get(reqHeadAll)
      } else if server.mappings.contains(reqHeadAllMethod) {
        server.mappings.get(reqHeadAllMethod)
      } else {
        match
          server.mappings
          .keys()
          .find_first(fn(key) {
            match @regexp.compile?(key) {
              Ok(compiled) => compiled.matches(request.path).success()
              _ => false
            }
          }) {
          Some(key) => server.mappings.get(key)
          None => server.mappings.get("ALL *")
        }
      },
    )
  })
  @http.listen!(server.port)
  println(
    @chalk.chalk()
    .color(@chalk.Green)
    .render("Server listening on port \{port}"),
  )
  println(
    @chalk.chalk().color(@chalk.Blue).render("Local: http://127.0.0.1:\{port}/"),
  )
  server
}

///|
fn handleFunc(
  self : HttpServer,
  reqMethod : String,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  self.mappings[reqMethod + " " + mapping] = handler
  @http.handle(reqMethod, mapping)
}

///|
pub fn get(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "GET", mapping, handler)
}

///|
pub fn post(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "POST", mapping, handler)
}

///|
pub fn put(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "PUT", mapping, handler)
}

///|
pub fn delete(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "DELETE", mapping, handler)
}

///|
pub fn patch(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "PATCH", mapping, handler)
}

///|
pub fn options(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "OPTIONS", mapping, handler)
}

///|
pub fn head(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "HEAD", mapping, handler)
}

///|
pub fn trace(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "TRACE", mapping, handler)
}

///|
pub fn connect(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "CONNECT", mapping, handler)
}

///|
pub fn all(
  self : HttpServer,
  mapping : String,
  handler : (@http.HttpRequest, @http.HttpResponse) -> Json!Async
) -> Unit {
  handleFunc(self, "ALL", mapping, handler)
}

///|
pub fn resource(self : HttpServer, from : String, to : String) -> Unit {
  println(@chalk.chalk().color(@chalk.Yellow).render("Route \{from} -> \{to}"))
  let fromRegExp : String = "\{from}.*"
  self.mappings[fromRegExp] = fn(req, _res) {
    file(to + req.path.substring(start=from.length()))
  }
}
