///|
pub fn serve(self : Mocket, port~ : Int) -> Unit {
  createServer(
    fn(req, res, _) {
      // 优化：简化 headers 转换逻辑
      let string_headers = {}
      guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
        res.writeHead(400, @js.Object::new().to_value())
        res.end("Invalid headers")
        return
      }

      // 批量转换 headers，减少单个处理的开销
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
        res: { statusCode: 200, headers: {} },
        params: {},
      }

      // 查找匹配的路由
      guard self.find_route(req.reqMethod(), req.url())
        is Some((handler, params)) else {
        res.writeHead(404, @js.Object::new().to_value())
        res.end("Not Found")
        return
      }

      // 设置路径参数
      event.params = params
      run(fn() {
        // 如果是 post，先等待 data 事件
        if event.req.reqMethod == "POST" {
          let body = suspend(fn(res, _) {
            let buffer = @buffer.new()
            req.on("data", fn(data) { buffer.write_string(data.to_string()) })
            req.on("end", fn(_) { res(buffer.to_string()) })
          }) catch {
            _ => panic()
          }
          event.req.body = body
        }

        // 执行中间件链
        execute_middlewares(self.middlewares, event)
        let response = handler(event)
        let body = match response {
          { "__": String(contentType), "body": body, .. } => {
            event.res.headers.set("Content-Type", contentType)
            body
          }
          _ => {
            match response {
              Json::Object(_) =>
                event.res.headers.set(
                  "Content-Type", "application/json;charset=UTF-8",
                )
              _ =>
                event.res.headers.set(
                  "Content-Type", "text/plain;charset=UTF-8",
                )
            }
            response
          }
        }
        let body_str = if body is String(str) { str } else { body.stringify() }
        res.writeHead(
          event.res.statusCode,
          (try? @js.Value::from_json(event.res.headers.to_json())).or(
            @js.Object::new().to_value(),
          ),
        )
        res.end(body_str)
      })
    },
    port,
  )
}
