// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Simple WebSocket echo server example
/// 
/// This server accepts WebSocket connections on localhost:9001
/// and echoes back any messages it receives.
///
/// You can test it with a JavaScript client in a web browser:
/// ```javascript
/// const ws = new WebSocket('ws://localhost:9001');
/// ws.onopen = function() {
///     console.log('Connected');
///     ws.send('Hello, WebSocket!');
/// };
/// ws.onmessage = function(event) {
///     console.log('Received:', event.data);
/// };
/// ```
async fn main {
  start_echo_server()
}

///|
/// Start the WebSocket echo server
/// This function starts a server that listens on localhost:9001
/// and echoes back any messages it receives from clients
async fn start_echo_server() -> Unit {
  println("Starting WebSocket echo server on localhost:9001")
  let server = @http.Server(@socket.Addr::parse("0.0.0.0:9001"))
  server.run_forever((request, _, conn) => {
    let client_addr = conn.client_addr()
    println("New WebSocket connection from \{client_addr}")
    let ws = @websocket.from_http_server(request, conn)
    defer ws.close()
    try {
      for ;; {
        let msg = ws.recv()
        match msg.kind {
          Text => {
            let text = msg.read_all().text()
            println("Received text \{text.char_length()} chars")
            ws.send_text(text)
          }
          Binary => {
            let data = msg.read_all().binary()
            println("Received binary data (\{data.length()} bytes)")
            ws.send_binary(data)
          }
        }
      }
    } catch {
      @websocket.ConnectionClosed(e, reason) =>
        println(
          "Client \{client_addr} disconnected with \{e}, reason: \{reason}",
        )
      e => println("Error with client \{client_addr}: \{e}")
    }
  })
}
