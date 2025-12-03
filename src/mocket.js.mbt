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
extern "js" fn set_js_property(
  obj : @js.Value,
  key : String,
  value : @js.Value,
) -> Unit = "(obj, key, value) => obj[key] = value"

///|
extern "js" fn array_to_js(arr : Array[String]) -> @js.Value = "(arr) => arr"

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
type NodeServerInternal

///|
#module("node:http")
extern "js" fn create_server(
  handler : (HttpRequestInternal, HttpResponseInternal, () -> Unit) -> Unit,
) -> NodeServerInternal = "createServer"

///|
pub extern "js" fn start_server(
  server : NodeServerInternal,
  port : Int,
  accept_key : (String) -> String,
) -> Unit =
  #|(server, port, acceptKey) => { 
  #|    function start(server, port) {
  #|      const clientsById = new Map();
  #|    
  #|      // 供 FFI 调用的发送函数
  #|      function sendText(socket, str) {
  #|        const payload = Buffer.from(String(str), 'utf8');
  #|        sendFrame(socket, payload, 0x1);
  #|      }
  #|
  #|      function sendBinary(socket, bytes) {
  #|        const payload = Buffer.from(bytes);
  #|        sendFrame(socket, payload, 0x2);
  #|      }
  #|
  #|      function sendPong(socket) {
  #|        const payload = Buffer.alloc(0);
  #|        sendFrame(socket, payload, 0xA);
  #|      }
  #|
  #|      function sendFrame(socket, payload, opcode) {
  #|        const len = payload.length;
  #|        let header;
  #|        if (len < 126) {
  #|          header = Buffer.alloc(2);
  #|          header[0] = 0x80 | opcode; // FIN + opcode
  #|          header[1] = len;
  #|        } else if (len < 65536) {
  #|          header = Buffer.alloc(4);
  #|          header[0] = 0x80 | opcode;
  #|          header[1] = 126;
  #|          header.writeUInt16BE(len, 2);
  #|        } else {
  #|          header = Buffer.alloc(10);
  #|          header[0] = 0x80 | opcode;
  #|          header[1] = 127;
  #|          header.writeBigUInt64BE(BigInt(len), 2);
  #|        }
  #|        try {
  #|          socket.write(Buffer.concat([header, payload]));
  #|        } catch (_) {}
  #|      }
  #|    
  #|      function parseFrame(buf) {
  #|        if (!Buffer.isBuffer(buf) || buf.length < 2) return null;
  #|        const fin = (buf[0] & 0x80) !== 0;
  #|        const opcode = buf[0] & 0x0f;
  #|        const masked = (buf[1] & 0x80) !== 0;
  #|        let len = buf[1] & 0x7f;
  #|        let offset = 2;
  #|        if (len === 126) {
  #|          if (buf.length < 4) return null;
  #|          len = buf.readUInt16BE(2);
  #|          offset = 4;
  #|        } else if (len === 127) {
  #|          if (buf.length < 10) return null;
  #|          const big = buf.readBigUInt64BE(2);
  #|          len = Number(big);
  #|          offset = 10;
  #|        }
  #|        if (masked) {
  #|          if (buf.length < offset + 4 + len) return null;
  #|          const mask = buf.slice(offset, offset + 4);
  #|          const data = buf.slice(offset + 4, offset + 4 + len);
  #|          const out = Buffer.alloc(len);
  #|          for (let i = 0; i < len; i++) out[i] = data[i] ^ mask[i % 4];
  #|          return { fin, opcode, data: out };
  #|        } else {
  #|          if (buf.length < offset + len) return null;
  #|          const data = buf.slice(offset, offset + len);
  #|          return { fin, opcode, data };
  #|        }
  #|      }
  #|    
  #|      // 导出四个 FFI 函数，供 MoonBit 调用
  #|      if (!globalThis.ws_port_bindings) globalThis.ws_port_bindings = new Map();
  #|      globalThis.ws_port_bindings.set(port, {
  #|        send: (id, msg) => {
  #|          const s = clientsById.get(id);
  #|          if (s) sendText(s, msg);
  #|        },
  #|        sendBytes: (id, bytes) => {
  #|          const s = clientsById.get(id);
  #|          if (s) sendBinary(s, bytes);
  #|        },
  #|        pong: (id) => {
  #|          const s = clientsById.get(id);
  #|          if (s) sendPong(s);
  #|        }
  #|      });
  #|    
  #|      server.on('upgrade', (req, socket, head) => {
  #|        const upgrade = (req.headers['upgrade'] || req.headers['Upgrade'] || '').toString();
  #|        if (upgrade !== 'websocket' && upgrade !== 'WebSocket') {
  #|          try { socket.destroy(); } catch (_) {}
  #|          return;
  #|        }
  #|        const key = req.headers['sec-websocket-key'] || req.headers['Sec-WebSocket-Key'];
  #|        if (!key) { try { socket.destroy(); } catch (_) {} return; }
  #|        const accept = acceptKey(key.toString());
  #|        const headers = [
  #|          'HTTP/1.1 101 Switching Protocols',
  #|          'Upgrade: websocket',
  #|          'Connection: Upgrade',
  #|          'Sec-WebSocket-Accept: ' + accept,
  #|          '\r\n'
  #|        ];
  #|        try { socket.write(headers.join('\r\n')); } catch (_) {
  #|          try { socket.destroy(); } catch (_) {} return;
  #|        }
  #|    
  #|        // 生成唯一连接 ID，注册到全局映射
  #|        const connectionId = crypto.randomUUID();
  #|        clientsById.set(connectionId, socket);
  #|    
  #|        // 派发 open 事件到 MoonBit
  #|        // console.log('[ws-bridge] emit open', port, connectionId);
  #|        if (typeof globalThis.__ws_emit_port === 'function') {
  #|          globalThis.__ws_emit_port('open', port, connectionId, '');
  #|        } else {
  #|          // console.log('[ws-bridge] __ws_emit not found');
  #|        }
  #|    
  #|        socket.on('data', (buf) => {
  #|          const frame = parseFrame(buf);
  #|          if (!frame) return;
  #|          // Close frame
  #|          if (frame.opcode === 0x8) {
  #|            try { socket.end(); } catch (_) {}
  #|            if (clientsById.delete(connectionId)) {
  #|              if (typeof globalThis.__ws_emit_port === 'function') {
  #|                globalThis.__ws_emit_port('close', port, connectionId, Buffer.alloc(0));
  #|              }
  #|          }
  #|         return;
  #|       }
  #|          // Ping -> Pong
  #|          if (frame.opcode === 0x9) {
  #|            // Emit ping event
  #|            if (typeof globalThis.__ws_emit_port === 'function') {
  #|              globalThis.__ws_emit_port('ping', port, connectionId, Buffer.alloc(0));
  #|            }
  #|            return;
  #|          }
  #|          // Text
  #|          if (frame.opcode === 0x1) {
  #|            const msg = frame.data || Buffer.alloc(0);
  #|            if (typeof globalThis.__ws_emit_port === 'function') {
  #|              globalThis.__ws_emit_port('message', port, connectionId, msg);
  #|            }
  #|          }
  #|          // Binary
  #|          if (frame.opcode === 0x2) {
  #|            const msg = frame.data || Buffer.alloc(0);
  #|            if (typeof globalThis.__ws_emit_port === 'function') {
  #|              globalThis.__ws_emit_port('binary', port, connectionId, msg);
  #|            }
  #|          }
  #|        });
  #|    
  #|        socket.on('close', () => {
  #|          if (clientsById.delete(connectionId)) {
  #|            if (typeof globalThis.__ws_emit_port === 'function') {
  #|              globalThis.__ws_emit_port('close', port, connectionId, Buffer.alloc(0));
  #|            }
  #|          }
  #|        });
  #|        socket.on('error', () => {
  #|          clientsById.delete(connectionId);
  #|          try { socket.destroy(); } catch (_) {}
  #|        });
  #|      });
  #|    
  #|      // console.log('[ws-bridge] WebSocket upgrade handler attached for port', port);
  #|    };
  #|    start(server, port); server.listen(port, () => {});
  #|}

///|
pub fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  let server = create_server(fn(req, res, _) {
    // 优化：简化 headers 转换逻辑
    let string_headers : Map[StringView, StringView] = {}
    guard (try? req.headers().to_value().to_json()) is Ok(Object(headers)) else {
      res.write_head(400, @js.Object::new().to_value())
      res.end(@js.Value::cast_from("Invalid headers"))
      return
    }

    // 批量转换 headers，减少单个处理的开销
    headers.each(fn(key, value) {
      if value is String(v) {
        string_headers.set(key, v.to_string_view())
      }
    })
    let (params, handler) = match
      mocket.find_route(req.req_method(), req.url()) {
      Some((h, p)) => (p, h)
      _ => ({}, handle_not_found)
    }
    let event = {
      req: {
        http_method: req.req_method(),
        url: req.url(),
        headers: string_headers,
        raw_body: "",
      },
      res: HttpResponse::new(OK),
      params,
    }
    async_run(() => {
      // 如果是 post，先等待 data 事件
      if event.req.http_method == "POST" {
        let buffer = @buffer.new()
        (try? suspend(fn(res, _) {
          req.on("data", data => buffer.write_string(data.to_string()))
          req.on("end", _ => res(buffer.to_string()))
        }))
        |> ignore
        event.req.raw_body = buffer.to_bytes()
      }

      // 执行中间件链和处理器
      let responder = execute_middlewares(mocket.middlewares, event, handler)
      // let boundary = "----------------moonbit-" + port.to_string()
      responder.options(event.res)
      res.write_head(
        event.res.status_code.to_int(),
        {
          let headers_obj = (try? @js.Value::from_json(
            event.res.headers.to_json(),
          )).or(@js.Object::new().to_value())
          if not(event.res.cookies.is_empty()) {
            let cookies = event.res.cookies
              .values()
              .map(fn(c) { c.to_string() })
              .to_array()
            set_js_property(headers_obj, "Set-Cookie", array_to_js(cookies))
          }
          headers_obj
        },
      )
      let buf = @buffer.new()
      responder.output(buf)
      event.res.raw_body = buf.to_bytes()
      res.end(@js.Value::cast_from(event.res.raw_body))
    })
  })
  start_server(server, port, websocket_accept_key)
  register_ws_handler(mocket, port)
  __ws_emit_js_export(__ws_emit_js_port)
  __ws_state_js_export(
    __ws_subscribe_js, __ws_unsubscribe_js, __ws_get_members_js,
  )
  __get_port_by_connection_js_export(__get_port_by_connection_js)
}

///|
fn websocket_accept_key(key : String) -> String {
  let guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  (key + guid)
  |> @encoding/utf8.encode
  |> @crypto.sha1
  |> Bytes::from_array
  |> @base64.encode
}

///|
/// 全局 handler 映射：port -> WebSocketHandler
let ws_handler_map : Map[Int, WebSocketHandler] = Map::new()

///|
let ws_mocket_map : Map[Int, Mocket] = Map::new()

///|
extern "js" fn _init_bindings_map() -> @js.Value = "() => { if (!globalThis.ws_port_bindings) globalThis.ws_port_bindings = new Map(); return globalThis.ws_port_bindings; }"

///|
/// 在 serve_ffi 里注册 WS handler（只取第一个静态路由）
pub fn register_ws_handler(mocket : Mocket, port : Int) -> Unit {
  let mut done = false
  mocket.ws_static_routes.each(fn(_, handler) {
    if not(done) {
      ws_handler_map.set(port, handler)
      ws_mocket_map.set(port, mocket)
      ignore(_init_bindings_map())
      done = true
    }
  })
}

///|
/// 供 JS 调用的 MoonBit 事件入口：捕获异常，避免抛回 JS
pub fn __ws_emit_js_port(
  event_type : String,
  port : Int,
  connection_id : String,
  payload : Bytes,
) -> Unit {
  let handler = match ws_handler_map.get(port) {
    Some(h) => h
    None => fn(_) {  }
  }
  let mocket = match ws_mocket_map.get(port) {
    Some(m) => m
    None => new()
  }
  match event_type {
    "open" => {
      mocket.ws_clients.set(connection_id, ())
      mocket.ws_client_port.set(connection_id, port)
    }
    "close" => {
      ignore(mocket.ws_clients.remove(connection_id))
      ignore(mocket.ws_client_port.remove(connection_id))
      mocket.ws_channels.each((_ch, set) => if set.get(connection_id) is Some(_) {
        ignore(set.remove(connection_id))
      })
    }
    _ => ()
  }
  let peer = WebSocketPeer::{ connection_id, subscribed_channels: [] }
  match event_type {
    "open" => handler(WebSocketEvent::Open(peer))
    "message" => {
      let msg = @encoding/utf8.decode(payload) catch { _ => "" }
      handler(WebSocketEvent::Message(peer, Text(msg)))
    }
    "binary" => handler(WebSocketEvent::Message(peer, Binary(payload)))
    "ping" => handler(WebSocketEvent::Message(peer, Ping))
    "close" => handler(WebSocketEvent::Close(peer))
    _ => ()
  }
}

///|
/// 导出 MoonBit 函数到 JS 全局
pub extern "js" fn __ws_emit_js_export(
  cb : (String, Int, String, Bytes) -> Unit,
) -> Unit = "(cb) => { globalThis.__ws_emit_port = (type, port, id, payload) => { try { cb(type, port, id, payload); } catch (_) {} }; }"

///|
pub fn __ws_subscribe_js(connection_id : String, channel : String) -> Unit {
  let mut mocket = new()
  ws_mocket_map.each(fn(_, m) {
    if m.ws_clients.get(connection_id) is Some(_) {
      mocket = m
    }
  })
  match mocket.ws_channels.get(channel) {
    Some(set) => set.set(connection_id, ())
    None => {
      let set : Map[String, Unit] = {}
      set.set(connection_id, ())
      mocket.ws_channels.set(channel, set)
    }
  }
}

///|
pub fn __ws_unsubscribe_js(connection_id : String, channel : String) -> Unit {
  let mut mocket = new()
  ws_mocket_map.each(fn(_, m) {
    if m.ws_clients.get(connection_id) is Some(_) {
      mocket = m
    }
  })
  match mocket.ws_channels.get(channel) {
    Some(set) => ignore(set.remove(connection_id))
    None => ()
  }
}

///|
pub fn __ws_get_members_js(channel : String) -> Array[String] {
  let mut mocket = new()
  ws_mocket_map.each(fn(_, m) {
    match m.ws_channels.get(channel) {
      Some(_) => mocket = m
      None => ()
    }
  })
  match mocket.ws_channels.get(channel) {
    Some(set) => set.keys().collect()
    None => []
  }
}

///|
pub extern "js" fn __ws_state_js_export(
  sub : (String, String) -> Unit,
  unsub : (String, String) -> Unit,
  get_members : (String) -> Array[String],
) -> Unit = "(sub, unsub, get_members) => { globalThis.__ws_subscribe_js = (id, ch) => { try { sub(id, ch); } catch (_) {} }; globalThis.__ws_unsubscribe_js = (id, ch) => { try { unsub(id, ch); } catch (_) {} }; globalThis.__ws_get_members_js = (ch) => { try { return get_members(ch); } catch (_) { return []; } }; }"

///|
pub fn __get_port_by_connection_js(id : String) -> Int {
  let mut found = 0
  ws_mocket_map.each(fn(p, m) {
    if m.ws_clients.get(id) is Some(_) {
      found = p
    }
  })
  found
}

///|
pub extern "js" fn __get_port_by_connection_js_export(
  cb : (String) -> Int,
) -> Unit = "(cb) => { globalThis.__get_port_by_connection = (id) => { try { return cb(id); } catch (_) { return 0 } } }"

///|
/// 四个 FFI 包装，供 WebSocketPeer 调用
pub extern "js" fn ws_send(id : String, msg : String) -> Unit = "(id, msg) => { const port = globalThis.__get_port_by_connection(id); const bindings = globalThis.ws_port_bindings && globalThis.ws_port_bindings.get(port); if (bindings && bindings.send) bindings.send(id, msg); }"

///|
pub extern "js" fn ws_send_bytes(id : String, msg : Bytes) -> Unit = "(id, msg) => { const port = globalThis.__get_port_by_connection(id); const bindings = globalThis.ws_port_bindings && globalThis.ws_port_bindings.get(port); if (bindings && bindings.sendBytes) bindings.sendBytes(id, msg); }"

///|
pub extern "js" fn ws_pong(id : String) -> Unit = "(id) => { const port = globalThis.__get_port_by_connection(id); const bindings = globalThis.ws_port_bindings && globalThis.ws_port_bindings.get(port); if (bindings && bindings.pong) bindings.pong(id); }"

///|
pub extern "js" fn ws_subscribe(id : String, channel : String) -> Unit = "(id, ch) => { if (globalThis.__ws_subscribe_js) globalThis.__ws_subscribe_js(id, ch); }"

///|
pub extern "js" fn ws_unsubscribe(id : String, channel : String) -> Unit = "(id, ch) => { if (globalThis.__ws_unsubscribe_js) globalThis.__ws_unsubscribe_js(id, ch); }"

///|
pub extern "js" fn ws_publish(channel : String, msg : String) -> Unit = "(ch, msg) => { const ids = globalThis.__ws_get_members_js ? globalThis.__ws_get_members_js(ch) : []; const bindings = globalThis.ws_port_bindings && globalThis.ws_port_bindings.values().next().value; if (bindings && bindings.send) { for (const id of ids) { bindings.send(id, msg); } } }"

///|
pub fn encode_multipart(
  m : Map[String, MultipartFormValue],
  boundary : String,
) -> String {
  let sb = StringBuilder::new()
  m.each(fn(name, v) {
    sb.write_string("--" + boundary + "\r\n")
    sb.write_string("Content-Disposition: form-data; name=\"" + name + "\"")
    match v.filename {
      Some(fnm) => sb.write_string("; filename=\"" + fnm + "\"")
      None => ()
    }
    sb.write_string("\r\n")
    match v.content_type {
      Some(ct) => sb.write_string("Content-Type: " + ct + "\r\n")
      None => ()
    }
    sb.write_string("\r\n")
    sb.write_string(@encoding/utf8.decode(v.data) catch { _ => "" })
    sb.write_string("\r\n")
  })
  sb.write_string("--" + boundary + "--\r\n")
  sb.to_string()
}
