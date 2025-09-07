///|
#external
pub type HttpRequestInternal

///|
#external
pub type HttpResponseInternal

///|
pub extern "js" fn HttpResponseInternal::url(
  self : HttpResponseInternal,
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::url(
  self : HttpRequestInternal,
) -> String = "(s) => s.url"

///|
pub extern "js" fn HttpRequestInternal::req_method(
  self : HttpRequestInternal,
) -> String = "(s) => s.method"

///|
extern "js" fn HttpRequestInternal::on(
  self : HttpRequestInternal,
  event : String,
  handler : (@js.Value) -> Unit,
) -> Unit = "(s, event, handler) => s.on(event, handler)"

///|
extern "js" fn HttpRequestInternal::headers(
  self : HttpRequestInternal,
) -> @js.Object = "(s) => s.headers"

///|
// extern "js" fn HttpResponseInternal::status_code(
//   self : HttpResponseInternal,
// ) -> Int = "(s) => s.statusCode"

///|
pub extern "js" fn HttpResponseInternal::end(
  self : HttpResponseInternal,
  data : @js.Value,
) -> Unit = "(s, data) => s.end(data)"

///|
extern "js" fn HttpResponseInternal::write_head(
  self : HttpResponseInternal,
  statusCode : Int,
  headers : @js.Value,
) -> Unit = "(s, statusCode, headers) => s.writeHead(statusCode, headers)"

///|
pub extern "js" fn create_server(
  handler : (HttpRequestInternal, HttpResponseInternal, () -> Unit) -> Unit,
  port : Int,
) -> Unit = "(handler, port) => require('node:http').createServer(handler).listen(port, () => {})"

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  create_server(
    fn(req, res, _) {
      // 优化：简化 headers 转换逻辑
      let string_headers = {}
      guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
        res.write_head(400, @js.Object::new().to_value())
        res.end(@js.Value::cast_from("Invalid headers"))
        return
      }

      // 批量转换 headers，减少单个处理的开销
      headers.each(fn(key, value) {
        if value is String(v) {
          string_headers.set(key, v)
        }
      })
      let (params, handler) = match
        mocket.find_route(req.req_method(), req.url()) {
        Some((h, p)) => (p, h)
        _ => {
          res.write_head(404, @js.Object::new().to_value())
          res.end(@js.Value::cast_from("Not Found"))
          return
        }
      }
      let event = {
        req: {
          http_method: req.req_method(),
          url: req.url(),
          body: Empty,
          headers: string_headers,
        },
        res: { status_code: 200, headers: {} },
        params,
      }
      let content_type = event.req.headers.get("Content-Type")
      run(fn() {
        // 如果是 post，先等待 data 事件
        if event.req.http_method == "POST" {
          let buffer = @buffer.new()
          (try? suspend(fn(res, _) {
            req.on("data", data => buffer.write_string(data.to_string()))
            req.on("end", _ => res(buffer.to_string()))
          }))
          |> ignore
          match content_type {
            Some("application/json") =>
              event.req.body = Json(
                @json.parse(buffer.to_string()) catch {
                  _ => {}
                },
              )
            Some("text/html") => event.req.body = HTML(buffer.to_string())
            Some("text/plain") => event.req.body = Text(buffer.to_string())
            _ => event.req.body = Bytes(buffer.to_bytes())
          }
        }

        // 执行中间件链
        execute_middlewares(mocket.middlewares, event)
        let body = handler(event)
        if not(body is Empty) {
          event.res.headers.set(
            "Content-Type",
            match body {
              Bytes(_) => "application/octet-stream"
              HTML(_) => "text/html; charset=utf-8"
              Text(_) => "text/plain; charset=utf-8"
              Json(_) => "application/json; charset=utf-8"
              Empty => ""
            },
          )
        }
        res.write_head(
          event.res.status_code,
          (try? @js.Value::from_json(event.res.headers.to_json())).or(
            @js.Object::new().to_value(),
          ),
        )
        res.end(
          match body {
            Bytes(b) => @js.Value::cast_from(b)
            HTML(s) => @js.Value::cast_from(s)
            Text(s) => @js.Value::cast_from(s)
            Json(j) => @js.Value::cast_from(j.stringify())
            Empty => @js.Value::cast_from("")
          },
        )
      })
    },
    port,
  )
}
