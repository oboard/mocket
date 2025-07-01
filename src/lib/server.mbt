///|
pub suberror IOError derive(Show)

///|
pub suberror NetworkError derive(Show)

///|
pub suberror ExecError derive(Show)

///|
fn run_async(f : async () -> Unit) -> Unit = "%async.run"

///|
pub(all) struct Mocket {
  mappings : Map[(String, String), async (HttpEvent) -> Json]
}

///|
pub typealias Mocket as T

///|
pub fn new() -> Mocket {
  { mappings: {} }
}

///|
pub struct HttpRequest {
  reqMethod : String
  url : String
  // headers : Map[String, String]
  // body : String
}

///|
pub struct HttpResponse {
  statusCode : Int
  headers : Map[String, String]
  // body : String
}

///|
pub struct HttpEvent {
  req : HttpRequest
  res : HttpResponse
}

///|
pub fn on(
  self : Mocket,
  event : String,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.mappings.set((event, path), handler)
}

///|
pub fn get(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("GET", path, handler)
}

///|
pub fn serve(self : Mocket, port~ : Int) -> Unit {
  createServer(
    fn(req, res, _) {
      let event = {
        req: { reqMethod: req.reqMethod(), url: req.url() },
        res: { statusCode: res.statusCode(), headers: {} },
      }
      guard self.mappings.get((req.reqMethod(), req.url())) is Some(handler) else {
        res.writeHead(404, @js.Object::new().to_value())
        res.end("")
      }
      run_async(fn() {
        let result = handler(event)
        let result_str = match result {
          String(str) => str
          _ => result.stringify()
        }
        match result {
          Json::Object(_) =>
            event.res.headers.set(
              "Content-Type", "application/json;charset=UTF-8",
            )
          _ => event.res.headers.set("Content-Type", "text/plain;charset=UTF-8")
        }
        res.writeHead(
          200,
          (try? @js.Value::from_json(event.res.headers.to_json())).or(
            @js.Object::new().to_value(),
          ),
        )
        res.end(result_str)
      })
    },
    port,
  )
}
