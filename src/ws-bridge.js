// ws-bridge.js - WebSocket 升级桥接，供 MoonBit JS 后端调用
module.exports = function start() {
  const http = require('node:http');
  const crypto = require('node:crypto');
  const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  // 复用全局 HTTP 服务器实例
  const server = globalThis.MOCKET_HTTP_SERVER;
  if (!server) {
    console.error('[ws-bridge] MOCKET_HTTP_SERVER not found');
    return;
  }

  // 全局 WebSocket 状态
  globalThis.WS = {
    clientsById: new Map(),   // Map<string, socket>
    channels: new Map(),      // Map<string, Set<string>>
  };

  function acceptKey(key) {
    return crypto.createHash('sha1').update(String(key) + GUID).digest('base64');
  }

  // 供 FFI 调用的发送函数
  function sendText(socket, str) {
    const payload = Buffer.from(String(str), 'utf8');
    const len = payload.length;
    let header;
    if (len < 126) {
      header = Buffer.alloc(2);
      header[0] = 0x81; // FIN + text
      header[1] = len;
    } else if (len < 65536) {
      header = Buffer.alloc(4);
      header[0] = 0x81;
      header[1] = 126;
      header.writeUInt16BE(len, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x81;
      header[1] = 127;
      header.writeBigUInt64BE(BigInt(len), 2);
    }
    try {
      socket.write(Buffer.concat([header, payload]));
    } catch (_) {}
  }

  function parseFrame(buf) {
    if (!Buffer.isBuffer(buf) || buf.length < 2) return null;
    const fin = (buf[0] & 0x80) !== 0;
    const opcode = buf[0] & 0x0f;
    const masked = (buf[1] & 0x80) !== 0;
    let len = buf[1] & 0x7f;
    let offset = 2;
    if (len === 126) {
      if (buf.length < 4) return null;
      len = buf.readUInt16BE(2);
      offset = 4;
    } else if (len === 127) {
      if (buf.length < 10) return null;
      const big = buf.readBigUInt64BE(2);
      len = Number(big);
      offset = 10;
    }
    if (masked) {
      if (buf.length < offset + 4 + len) return null;
      const mask = buf.slice(offset, offset + 4);
      const data = buf.slice(offset + 4, offset + 4 + len);
      const out = Buffer.alloc(len);
      for (let i = 0; i < len; i++) out[i] = data[i] ^ mask[i % 4];
      return { fin, opcode, data: out };
    } else {
      if (buf.length < offset + len) return null;
      const data = buf.slice(offset, offset + len);
      return { fin, opcode, data };
    }
  }

  // 导出四个 FFI 函数，供 MoonBit 调用
  globalThis.ws_send = (id, msg) => {
    const s = globalThis.WS.clientsById.get(id);
    if (s) sendText(s, msg);
  };
  globalThis.ws_subscribe = (id, ch) => {
    let set = globalThis.WS.channels.get(ch);
    if (!set) { set = new Set(); globalThis.WS.channels.set(ch, set); }
    set.add(id);
  };
  globalThis.ws_unsubscribe = (id, ch) => {
    const set = globalThis.WS.channels.get(ch);
    if (set) { set.delete(id); if (set.size === 0) globalThis.WS.channels.delete(ch); }
  };
  globalThis.ws_publish = (ch, msg) => {
    const set = globalThis.WS.channels.get(ch);
    if (set) {
      for (const cid of set) {
        const s = globalThis.WS.clientsById.get(cid);
        if (s) sendText(s, msg);
      }
    }
  };

  server.on('upgrade', (req, socket, head) => {
    const upgrade = (req.headers['upgrade'] || req.headers['Upgrade'] || '').toString();
    if (upgrade !== 'websocket' && upgrade !== 'WebSocket') {
      try { socket.destroy(); } catch (_) {}
      return;
    }
    const key = req.headers['sec-websocket-key'] || req.headers['Sec-WebSocket-Key'];
    if (!key) { try { socket.destroy(); } catch (_) {} return; }
    const accept = acceptKey(key.toString());
    const headers = [
      'HTTP/1.1 101 Switching Protocols',
      'Upgrade: websocket',
      'Connection: Upgrade',
      'Sec-WebSocket-Accept: ' + accept,
      '\r\n'
    ];
    try { socket.write(headers.join('\r\n')); } catch (_) {
      try { socket.destroy(); } catch (_) {} return;
    }

    // 生成唯一连接 ID，注册到全局映射
    const connectionId = crypto.randomUUID();
    globalThis.WS.clientsById.set(connectionId, socket);

    // 派发 open 事件到 MoonBit
    console.log('[ws-bridge] emit open', connectionId);
    if (typeof globalThis.__ws_emit === 'function') {
      globalThis.__ws_emit('open', connectionId, '');
    } else {
      console.log('[ws-bridge] __ws_emit not found');
    }

    socket.on('data', (buf) => {
      const frame = parseFrame(buf);
      if (!frame) return;
      // Close frame
      if (frame.opcode === 0x8) {
        try { socket.end(); } catch (_) {}
        globalThis.WS.clientsById.delete(connectionId);
        for (const [_, set] of globalThis.WS.channels) set.delete(connectionId);
        if (typeof globalThis.__ws_emit === 'function') {
          globalThis.__ws_emit('close', connectionId, '');
        }
        return;
      }
      // Ping -> Pong
      if (frame.opcode === 0x9) {
        const payload = frame.data || Buffer.alloc(0);
        const header = Buffer.from([0x8A, payload.length]);
        try { socket.write(Buffer.concat([header, payload])); } catch (_) {}
        return;
      }
      // Text
      if (frame.opcode === 0x1) {
        const msg = (frame.data || Buffer.alloc(0)).toString('utf8');
        console.log('[ws-bridge] emit message', connectionId, msg);
        if (typeof globalThis.__ws_emit === 'function') {
          globalThis.__ws_emit('message', connectionId, msg);
        } else {
          console.log('[ws-bridge] __ws_emit not found');
        }
      }
    });

    socket.on('close', () => {
      globalThis.WS.clientsById.delete(connectionId);
      for (const [_, set] of globalThis.WS.channels) set.delete(connectionId);
      if (typeof globalThis.__ws_emit === 'function') {
        globalThis.__ws_emit('close', connectionId, '');
      }
    });
    socket.on('error', () => {
      globalThis.WS.clientsById.delete(connectionId);
      for (const [_, set] of globalThis.WS.channels) set.delete(connectionId);
      try { socket.destroy(); } catch (_) {}
    });
  });

  console.log('[ws-bridge] WebSocket upgrade handler attached');
};