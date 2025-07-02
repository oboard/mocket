///|
pub suberror IOError derive(Show)

///|
pub suberror NetworkError derive(Show)

///|
pub suberror ExecError derive(Show)

///|
fn run_async(f : async () -> Unit) -> Unit = "%async.run"

///| `suspend` 会中断当前协程的运行。
/// `suspend` 会接受一个回调函数，并让这个回调函数来操作中断的协程
async fn[T, E : Error] suspend(
  // `f` 是负责操作中断的协程的回调函数
  f : (
    // `f` 的第一个参数用于继续运行被中断的协程
    (T) -> Unit,
    // `f` 的第二个参数用于取消被中断的协程。
    // 取消会被表示为在中断处抛出错误
    (E) -> Unit,
  ) -> Unit
) -> T raise E = "%async.suspend"

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
  headers : Map[String, String]
  mut body : String
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
pub fn post(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("POST", path, handler)
}

///|
pub fn patch(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("PATCH", path, handler)
}

///|
pub fn connect(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("CONNECT", path, handler)
}

///|
pub fn put(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("PUT", path, handler)
}

///|
pub fn delete(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("DELETE", path, handler)
}

///|
pub fn head(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("HEAD", path, handler)
}

///|
pub fn options(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("OPTIONS", path, handler)
}

///|
pub fn trace(
  self : Mocket,
  path : String,
  handler : async (HttpEvent) -> Json
) -> Unit {
  self.on("TRACE", path, handler)
}

///|
pub fn serve(self : Mocket, port~ : Int) -> Unit {
  createServer(
    fn(req, res, _) {
      guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
        res.writeHead(400, @js.Object::new().to_value())
        res.end("Invalid headers")
        return
      }

      // 将 JSON headers 转换为字符串 headers
      let string_headers = {}
      headers.each(fn(key, value) {
        if value is String(v) {
          string_headers.set(key, v)
        }
      })
      let event = {
        req: {
          reqMethod: req.reqMethod(),
          url: req.url(),
          body: "",
          headers: string_headers,
        },
        res: { statusCode: res.statusCode(), headers: {} },
      }
      guard self.mappings.get((req.reqMethod(), req.url())) is Some(handler) else {
        res.writeHead(404, @js.Object::new().to_value())
        res.end("")
        return
      }
      run_async(fn() {
        // 如果是 post，先等待 data 事件
        if event.req.reqMethod == "POST" {
          let body = suspend(fn(res, _) {
            let buffer = @buffer.new()
            req.on("data", fn(data) { buffer.write_string(data.to_string()) })
            req.on("end", fn(_) { res(buffer.to_string()) })
          }) catch {
            err => abort(err)
          }
          event.req.body = body
        }
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
