pub struct HeavenBinding {
  mut listen : (String, (@json.JsonValue) -> Unit) -> Unit
  mut send : (String, @json.JsonValue) -> Unit
  mut call : (String, @json.JsonValue, (@json.JsonValue) -> Unit) -> Unit
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
  port : Int
  mappings : Map[String, (HttpRequest, HttpResponse) -> @json.JsonValue]
}

let binding : HeavenBinding = {
  listen: fn(_a, _b) { println("Please bind heaven.") },
  send: fn(_a, _b) { println("Please bind heaven.") },
  call: fn(_a, _b, _c) { println("Please bind heaven.") },
}

pub fn html(data : String) -> @json.JsonValue {
  { "_T": "html", "data": String(data) }
}

pub fn file(path : String) -> @json.JsonValue {
  { "_T": "file", "path": String(path) }
}

pub fn buffer(data : Bytes) -> @json.JsonValue {
  {
    "_T": "buffer",
    "data": data
    .to_array()
    .map(fn(n : Byte) -> @json.JsonValue { Number(n.to_int().to_double()) })
    |> Array,
  }
}

pub fn listen(
  context : (
    (String, (@json.JsonValue) -> Unit) -> Unit,
    (String, @json.JsonValue) -> Unit,
    (String, @json.JsonValue, (@json.JsonValue) -> Unit) -> Unit,
  ),
  port : Int
) -> HttpServer {
  binding.listen = context.0
  binding.send = context.1
  binding.call = context.2
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
                      Object({ "_T": "html", "data": data }) => {
                        response.writeHead(200, { "Content-Type": "text/html" })
                        response.end(data)
                      }
                      Object({ "_T": "file", "path": String(path) }) => {
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
              let reqHeadAll = "ALL " + urlObject.path
              let reqHeadAllMethod = method + " *"
              println(@chalk.chalk().color(Green).render(reqHead))
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
                    .find_first(
                      fn(key) {
                        match request.path {
                          Some(path) =>
                            match @regexp.compile?(key) {
                              Ok(compiled) => compiled.matches(path).success()
                              _ => false
                            }
                          None => false
                        }
                      },
                    ) {
                    Some(key) => server.mappings.get(key)
                    None => None
                  }
                  // server.mappings.get("ALL *")
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
  (binding.send)("http.listen", Number(server.port.to_double()))
  println(
    @chalk.chalk().color(Green).render("Server listening on port \{port}"),
  )
  println(
    @chalk.chalk().color(@chalk.Colors::Blue).render("Local: http://127.0.0.1:\{port}/"),
  )
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

// pub fn readDir(callback : (@json.JsonValue) -> Unit, path : String) -> Unit {
//   (binding.call)("fs.readDirSync", String(path), callback)
// }

pub fn readDir(path : String) -> Promise[@json.JsonValue] {
  Promise::new(
    fn(
      resolve : (@json.JsonValue) -> Unit,
      _reject : (@json.JsonValue) -> Unit
    ) {
      (binding.call)("fs.readDir", String(path), resolve)
    },
  )
}

pub fn readFile(path : String) -> Promise[Bytes] {
  Promise::new(
    fn(resolve, reject) {
      (binding.call)(
        "fs.readFile",
        String(path),
        fn {
          Array(bytes) =>
            bytes.map(
              fn {
                Number(n) => n.to_int().to_byte()
                _ => (0).to_byte()
              },
            )
            |> FixedArray::from_array
            |> Bytes::of
            |> resolve
          _ => reject(Bytes::new(0))
        },
      )
    },
  )
}

pub fn static(self : HttpServer, from : String, to : String) -> Unit {
  println(@chalk.chalk().color(Yellow).render("Route \{from} -> \{to}"))
  let fromRegExp : String = "\{from}.*"
  self.mappings[fromRegExp] = fn(req, res) {
    match req.path {
      Some(path) => file(to + path.substring(start=from.length()))
      _ => {
        res.writeHead(404, { "Content-Type": "text/plain" })
        String("Not Found")
      }
    }
  }
}
