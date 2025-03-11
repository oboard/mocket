///|
pub type! IOError  derive(Show)

///|
pub type! NetworkError  derive(Show)

///|
pub type! ExecError  derive(Show)

///|
fn run_async(f : async () -> Unit) -> Unit = "%async.run"

///|
async fn suspend[T, E : Error](f : ((T) -> Unit, (E) -> Unit) -> Unit) -> T!E = "%async.suspend"

///|
pub struct HeavenBinding {
  mut listen : (String, (Json) -> Unit) -> Unit
  mut send : (String, Json) -> Unit
  mut call : (String, Json, (Json) -> Unit) -> Unit
}

///|
pub struct HttpResponse {
  id : Double
  mut statusCode : Json
  mut headers : Json
}

///|
pub(all) struct HttpRequest {
  url : String?
  path : String?
  query : Map[String, String]
  body : Json?
}

///|
pub(all) struct HttpServer {
  port : Int
  mappings : Map[String, async (HttpRequest, HttpResponse) -> Json]
}

///|
let binding : HeavenBinding = {
  listen: fn(_a, _b) { println("Please bind heaven.") },
  send: fn(_a, _b) { println("Please bind heaven.") },
  call: fn(_a, _b, _c) { println("Please bind heaven.") },
}

///|
pub fn html(data : String) -> Json {
  { "_T": "html", "data": String(data) }
}

///|
pub fn file(path : String) -> Json {
  { "_T": "file", "path": String(path) }
}

///|
pub fn buffer(data : Bytes) -> Json {
  {
    "_T": "buffer",
    "data": data
    .to_array()
    .map(fn(n : Byte) -> Json { Number(n.to_int().to_double()) })
    |> Array,
  }
}

///|
pub fn listen(
  context : (
    (String, (Json) -> Unit) -> Unit,
    (String, Json) -> Unit,
    (String, Json, (Json) -> Unit) -> Unit,
  ),
  port : Int
) -> HttpServer {
  binding.listen = context.0
  binding.send = context.1
  binding.call = context.2
  let server = { port, mappings: {} }
  (binding.listen)("http.request", fn(result) {
    match result {
      [req, res] =>
        match (req, res) {
          (
            { "method": String(res_method), "url": String(url), .. },
            { "id": Number(id), .. },
          ) => {
            let urlObject = URL::parse(url)
            let request : HttpRequest = {
              url: Some(url),
              path: Some(urlObject.path),
              query: urlObject.query.or({}),
              body: match req {
                { "body": body, .. } => Some(body)
                _ => None
              },
            }
            let response : HttpResponse = { id, statusCode: 200, headers: {} }
            fn doHandler(reqFn : (async (HttpRequest, HttpResponse) -> Json)?) {
              match reqFn {
                Some(handler) =>
                  run_async(fn() {
                    let result = handler!!(request, response)
                    match result {
                      Object({ "_T": "html", "data": data, .. }) => {
                        response.writeHead(200, { "Content-Type": "text/html" })
                        response.end(data)
                      }
                      Object({ "_T": "file", "path": String(path), .. }) => {
                        let mime = @mimetype.T::new()
                        let mimeType = mime.getType(path)
                        response.writeHead(200, {
                          "Content-Type": mimeType.or(
                            "application/octet-stream",
                          )
                          |> String,
                        })
                        response.end(result)
                      }
                      Object(_) => {
                        response.writeHead(200, {
                          "Content-Type": "application/json",
                        })
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

            let reqHead = res_method + " " + urlObject.path
            let reqHeadAll = "ALL " + urlObject.path
            let reqHeadAllMethod = res_method + " *"
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
                    match request.path {
                      Some(path) =>
                        match @regexp.compile?(key) {
                          Ok(compiled) => compiled.matches(path).success()
                          _ => false
                        }
                      None => false
                    }
                  }) {
                  Some(key) => server.mappings.get(key)
                  None => server.mappings.get("ALL *")
                }
              },
            )
            response.end("Not Found")
          }
          _ => println("Invalid struct")
        }
      _ => println("Invalid request")
    }
  })
  (binding.send)("http.listen", Number(server.port.to_double()))
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
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  self.mappings[reqMethod + " " + mapping] = handler
  (binding.send)("http.handle", [String(reqMethod), String(mapping)])
}

///|
pub fn get(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "GET", mapping, handler)
}

///|
pub fn post(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "POST", mapping, handler)
}

///|
pub fn put(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "PUT", mapping, handler)
}

///|
pub fn delete(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "DELETE", mapping, handler)
}

///|
pub fn patch(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "PATCH", mapping, handler)
}

///|
pub fn options(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "OPTIONS", mapping, handler)
}

///|
pub fn head(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "HEAD", mapping, handler)
}

///|
pub fn trace(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "TRACE", mapping, handler)
}

///|
pub fn connect(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "CONNECT", mapping, handler)
}

///|
pub fn all(
  self : HttpServer,
  mapping : String,
  handler : async (HttpRequest, HttpResponse) -> Json
) -> Unit {
  handleFunc(self, "ALL", mapping, handler)
}

///|
pub fn writeHead(
  self : HttpResponse,
  statusCode : Json,
  headers : Json
) -> Unit {
  // (binding.send)("http.writeHead", [Number(self.id), statusCode, headers])
  self.statusCode = statusCode
  self.headers = headers
}

///|
pub fn end(self : HttpResponse, body : Json) -> Unit {
  (binding.send)("http.end", [
    Number(self.id),
    self.statusCode,
    self.headers,
    body,
  ])
}

///|
pub async fn readDir(path : String) -> Json!Error {
  suspend!!(fn(resolve, _reject) {
    (binding.call)("fs.readDir", String(path), resolve)
  })
}

// ///|
///|
pub async fn readFile(path : String) -> Bytes!Error {
  suspend!!(fn(resolve, reject) {
    (binding.call)("fs.readFile", String(path), fn {
      Array(bytes) =>
        bytes.map(fn {
          Number(n) => n.to_int().to_byte()
          _ => (0).to_byte()
        })
        |> FixedArray::from_array
        |> Bytes::of
        |> resolve
      _ => reject(IOError)
    })
  })
}

///|
pub async fn exec(cmd : String) -> String!Error {
  suspend!!(fn(resolve, reject) {
    (binding.call)("os.exec", String(cmd), fn {
      String(s) => resolve(s)
      _ => reject(ExecError)
    })
  })
}

///|
pub fn resource(self : HttpServer, from : String, to : String) -> Unit {
  println(@chalk.chalk().color(@chalk.Yellow).render("Route \{from} -> \{to}"))
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

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
}

///|
pub(all) enum FetchMode {
  CORS
  NoCORS
  SameOrigin
  Navigate
}

///|
struct FetchResponse {
  status : Int
  statusText : String
  headers : Map[String, String]
  data : String
} derive(ToJson, Show, Eq)

///|
pub async fn fetch(
  url : String,
  reqMethod? : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode
) -> FetchResponse!NetworkError {
  suspend!!(fn(resolve, reject) {
    let options : Map[String, Json] = {}
    match reqMethod {
      Some(str) => options["method"] = String(str)
      _ => ()
    }
    match body {
      Some(str) => options["body"] = String(str)
      _ => ()
    }
    match headers {
      Some(json) => options["headers"] = json.to_json()
      _ => ()
    }
    match credentials {
      Some(cred) =>
        options["credentials"] = match cred {
          Omit => String("omit")
          SameOrigin => String("same-origin")
          Include => String("include")
        }
      _ => ()
    }
    match mode {
      Some(m) =>
        options["mode"] = match m {
          CORS => String("cors")
          NoCORS => String("no-cors")
          SameOrigin => String("same-origin")
          Navigate => String("navigate")
        }
      _ => ()
    }
    (binding.call)("fetch", [[String(url), options.to_json()]], fn {
      Object(
        {
          "data": String(data),
          "statusText": String(statusText),
          "status": Number(status),
          "headers": Object(headers),
          ..
        }
      ) =>
        resolve(FetchResponse::{
          status: status.to_int(),
          statusText,
          headers: headers
          .iter()
          .map(fn(i : (String, Json)) -> (String, String) {
            (i.0, i.1.as_string().or(""))
          })
          .to_array()
          |> Map::from_array,
          data,
        })
      _ => reject(NetworkError)
    })
  })
}
