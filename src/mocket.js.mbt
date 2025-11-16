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
) -> Unit = "(handler, port) => { const server = require('node:http').createServer(handler); globalThis.MOCKET_HTTP_SERVER = server; require('./ws-bridge.js')(); server.listen(port, () => {}) }"

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
      run(fn() {
        // 如果是 post，先等待 data 事件
        if event.req.http_method == "POST" {
          let buffer = @buffer.new()
          (try? suspend(fn(res, _) {
            req.on("data", data => buffer.write_string(data.to_string()))
            req.on("end", _ => res(buffer.to_string()))
          }))
          |> ignore
          event.req.body = read_body(string_headers, buffer.to_bytes()) catch {
            _ => {
              res.write_head(400, @js.Object::new().to_value())
              res.end(@js.Value::cast_from("Invalid body"))
              return
            }
          }
        }

        // 执行中间件链和处理器
        let body = execute_middlewares(mocket.middlewares, event, handler)
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
            Bytes(b) => @js.Value::cast_from(b.to_bytes())
            HTML(s) => @js.Value::cast_from(s.to_string())
            Text(s) => @js.Value::cast_from(s.to_string())
            Json(j) => @js.Value::cast_from(j.stringify())
            Empty => @js.Value::cast_from("")
          },
        )
      })
    },
    port,
  )
  register_ws_handler(mocket, port)
  __ws_emit_js_export()
}

///|
/// 全局 handler 映射：port -> WebSocketHandler
let ws_handler_map : Map[Int, WebSocketHandler] = Map::new()

///|
/// 在 serve_ffi 里注册 WS handler（只取第一个静态路由）
pub fn register_ws_handler(mocket : Mocket, port : Int) -> Unit {
  let mut done = false
  mocket.ws_static_routes.each(fn(_, handler) {
    if not(done) {
      ws_handler_map.set(port, handler)
      done = true
    }
  })
}

///|
/// 供 JS 调用的 MoonBit 事件入口：捕获异常，避免抛回 JS
pub fn __ws_emit_js(
  event_type : String,
  connection_id : String,
  payload : String,
) -> Unit {
  // 拿第一个 handler（例子只注册一个端口）
  let handler = if ws_handler_map.is_empty() {
    fn(_) {  }
  } else {
    ws_handler_map.get(ws_handler_map.keys().collect()[0]).unwrap()
  }
  let peer = WebSocketPeer::{ connection_id, subscribed_channels: [] }
  match event_type {
    "open" => handler(WebSocketEvent::Open(peer))
    "message" => handler(WebSocketEvent::Message(peer, Text(payload)))
    "close" => handler(WebSocketEvent::Close(peer))
    _ => ()
  }
}

///|
/// 导出 MoonBit 函数到 JS 全局
pub extern "js" fn __ws_emit_js_export() -> Unit = "globalThis.__ws_emit = (type, id, payload) => { try { __ws_emit_js(type, id, payload); } catch (_) {} };"

///|
/// 在 JS 端启动 WebSocket 服务器（监听同端口，复用 HTTP 服务器的 server 实例）
pub extern "js" fn start_ws_server() -> Unit = "(function() { const http = require('node:http'); const crypto = require('node:crypto'); const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'; if (!globalThis.WS_SERVER_STARTED) { globalThis.WS_SERVER_STARTED = true; const server = globalThis.MOCKET_HTTP_SERVER; if (!server) return; function acceptKey(key) { return crypto.createHash('sha1').update(String(key) + GUID).digest('base64'); } function sendText(socket, str) { const payload = Buffer.from(String(str), 'utf8'); const len = payload.length; let header; if (len < 126) { header = Buffer.alloc(2); header[0] = 0x81; header[1] = len; } else if (len < 65536) { header = Buffer.alloc(4); header[0] = 0x81; header[1] = 126; header.writeUInt16BE(len, 2); } else { header = Buffer.alloc(10); header[0] = 0x81; header[1] = 127; header.writeBigUInt64BE(BigInt(len), 2); } try { socket.write(Buffer.concat([header, payload])); } catch (_) {} } function parseFrame(buf) { if (!Buffer.isBuffer(buf) || buf.length < 2) return null; const fin = (buf[0] & 0x80) !== 0; const opcode = buf[0] & 0x0f; const masked = (buf[1] & 0x80) !== 0; let len = buf[1] & 0x7f; let offset = 2; if (len === 126) { if (buf.length < 4) return null; len = buf.readUInt16BE(2); offset = 4; } else if (len === 127) { if (buf.length < 10) return null; const big = buf.readBigUInt64BE(2); len = Number(big); offset = 10; } if (masked) { if (buf.length < offset + 4 + len) return null; const mask = buf.slice(offset, offset + 4); const data = buf.slice(offset + 4, offset + 4 + len); const out = Buffer.alloc(len); for (let i = 0; i < len; i++) out[i] = data[i] ^ mask[i % 4]; return { fin, opcode, data: out }; } else { if (buf.length < offset + len) return null; const data = buf.slice(offset, offset + len); return { fin, opcode, data }; } } server.on('upgrade', (req, socket, head) => { const upgrade = (req.headers['upgrade'] || req.headers['Upgrade'] || '').toString(); if (upgrade !== 'websocket' && upgrade !== 'WebSocket') { try { socket.destroy(); } catch (_) {} return; } const key = req.headers['sec-websocket-key'] || req.headers['Sec-WebSocket-Key']; if (!key) { try { socket.destroy(); } catch (_) {} return; } const accept = acceptKey(key.toString()); const headers = ['HTTP/1.1 101 Switching Protocols', 'Upgrade: websocket', 'Connection: Upgrade', 'Sec-WebSocket-Accept: ' + accept, '\r\n']; try { socket.write(headers.join('\r\n')); } catch (_) { try { socket.destroy(); } catch (_) {} return; } const connectionId = crypto.randomUUID(); globalThis.WS.clientsById.set(connectionId, socket); if (typeof globalThis.__ws_emit === 'function') { globalThis.__ws_emit('open', connectionId); } socket.on('data', (buf) => { const frame = parseFrame(buf); if (!frame) return; if (frame.opcode === 0x8) { try { socket.end(); } catch (_) {} globalThis.WS.clientsById.delete(connectionId); for (const [_, set] of globalThis.WS.channels) set.delete(connectionId); if (typeof globalThis.__ws_emit === 'function') { globalThis.__ws_emit('close', connectionId); } return; } if (frame.opcode === 0x9) { const payload = frame.data || Buffer.alloc(0); const header = Buffer.from([0x8A, payload.length]); try { socket.write(Buffer.concat([header, payload])); } catch (_) {} return; } if (frame.opcode === 0x1) { const msg = (frame.data || Buffer.alloc(0)).toString('utf8'); if (typeof globalThis.__ws_emit === 'function') { globalThis.__ws_emit('message', connectionId, msg); } } }); socket.on('close', () => { globalThis.WS.clientsById.delete(connectionId); for (const [_, set] of globalThis.WS.channels) set.delete(connectionId); if (typeof globalThis.__ws_emit === 'function') { globalThis.__ws_emit('close', connectionId); } }); socket.on('error', () => { globalThis.WS.clientsById.delete(connectionId); for (const [_, set] of globalThis.WS.channels) set.delete(connectionId); try { socket.destroy(); } catch (_) {} }); }); } })()"

///|
/// 四个 FFI 包装，供 WebSocketPeer 调用
pub extern "js" fn ws_send(id : String, msg : String) -> Unit = "globalThis.ws_send"

///|
pub extern "js" fn ws_subscribe(id : String, channel : String) -> Unit = "globalThis.ws_subscribe"

///|
pub extern "js" fn ws_unsubscribe(id : String, channel : String) -> Unit = "globalThis.ws_unsubscribe"

///|
pub extern "js" fn ws_publish(channel : String, msg : String) -> Unit = "globalThis.ws_publish"
