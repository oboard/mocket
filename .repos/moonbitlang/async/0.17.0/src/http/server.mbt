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
/// A single HTTP server connection
struct ServerConnection {
  reader : Reader
  conn : @socket.Tcp
  sender : Sender
  mut closed : Bool
}

///|
/// Create a new HTTP server connection from a TCP connection.
///
/// `headers` can be used to specify persistent headers for the connection,
/// i.e. all response sent by this connection will share these headers.
/// The following headers is automatically set,
/// and must not be specified in `headers`:
/// 
/// - Content-Length, Transfer-Encoding
pub fn ServerConnection::new(
  conn : @socket.Tcp,
  headers? : Map[String, String] = {},
) -> ServerConnection {
  {
    reader: Reader::new(conn),
    conn,
    sender: Sender::new(conn, headers~),
    closed: false,
  }
}

///|
/// Close the connection, the underlying TCP connection will be closed as well.
/// This function is idempotent: it is safe to call `.close()` multiple times,
/// only the first `.close()` call takes effect.
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  if !self.closed {
    self.closed = true
    self.conn.close()
  }
}

///|
/// Get the address of client from a HTTP server connection
pub fn ServerConnection::client_addr(self : ServerConnection) -> @socket.Addr {
  self.conn.addr()
}

///|
pub impl @io.Reader for ServerConnection with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.reader._direct_read(buf, offset~, max_len~)
}

///|
pub impl @io.Reader for ServerConnection with _get_internal_buffer(self) {
  self.reader._get_internal_buffer()
}

///|
/// Read a single request from the connection.
/// If the body of the last request is not consumed yet,
/// it will be discarded.
///
/// After calling `read_request`,
/// the body of the request can be obtained by using `ServerConnection`
/// as a `@io.Reader`.
pub async fn ServerConnection::read_request(self : ServerConnection) -> Request {
  self.reader.skip_body()
  self.reader.read_request()
}

///|
/// Manually discard the body of the request currently being processed.
pub async fn ServerConnection::skip_request_body(
  self : ServerConnection,
) -> Unit {
  self.reader.skip_body()
}

///|
/// Write data to the body of the response currently being sent.
/// Must be called after `send_response`.
/// `end_response` must be called after all content of response body has been sent.
///
/// Writing to `@http.ServerConnection` MAY be buffered,
/// call `flush` manually to ensure data is delivered to the remote peer.
pub impl @io.Writer for ServerConnection with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  guard !(self.sender.mode is SendingHeader)
  self.sender.write_once(buf, offset~, len~)
}

///|
pub impl @io.Writer for ServerConnection with write_reader(self, reader) {
  guard !(self.sender.mode is SendingHeader)
  self.sender.write_reader(reader)
}

///|
/// Flush buffered data in the response body being sent, if any.
pub async fn ServerConnection::flush(self : ServerConnection) -> Unit {
  self.sender.flush()
}

///|
/// End the body of the response currently being sent.
/// Should be called immediately after response body is fully sent.
pub async fn ServerConnection::end_response(self : ServerConnection) -> Unit {
  self.sender.end_body()
}

///|
/// Send a response to the peer.
/// The `ServerConnection` can be used as a `@io.Writer` later for sending response body.
/// After calling `send_response`,
/// `end_response` must be called before sending the next response.
pub async fn ServerConnection::send_response(
  self : ServerConnection,
  code : Int,
  reason : String,
  extra_headers? : Map[String, String] = {},
) -> Unit {
  self.sender.send_response(code, reason, extra_headers~)
}

///|
/// A HTTP server
pub struct Server {
  addr : @socket.Addr
  priv server : @socket.TcpServer
  priv headers : Map[String, String]

  async fn new(
    addr : @socket.Addr,
    dual_stack? : Bool,
    reuse_addr? : Bool,
    headers? : Map[String, String],
  ) -> Server
}

///|
/// Create a new HTTP server listening on `addr`.
///
/// The meaning of `dual_stack` and `reuse_addr` is the same as
/// `@socket.TcpServer::new()`, see there for more details.
///
/// `headers` can be used to specify common headers
/// shared by all responses sent by this server.
pub async fn Server::new(
  addr : @socket.Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
  headers? : Map[String, String] = {},
) -> Server {
  let server = @socket.TcpServer::new(addr, dual_stack?, reuse_addr?)
  { addr: server.addr, server, headers }
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.server.close()
}

///|
/// Get the listen address of the server
#deprecated("use `.addr` instead")
pub fn Server::addr(self : Server) -> @socket.Addr {
  self.addr
}

///|
/// Accept a new connection from a HTTP server.
/// Return the new HTTP connection and the address of peer.
pub async fn Server::accept(self : Server) -> (ServerConnection, @socket.Addr) {
  let (conn, addr) = self.server.accept()
  (ServerConnection::new(conn, headers=self.headers), addr)
}

///|
/// Start the main loop of a HTTP server,
/// the server will keep listening for new connections
/// and new requests from existing connections.
/// Requests are handled by the callback function `f`.
///
/// The callback function `f` accepts three arguments:
/// - the request to process
/// - a `&@io.Reader` that can be used to read request body
/// - a `@http.ServerConnection` that can be used to send response.
///     The procedure to send a response is:
///     1. initiate a response and send response header via `.send_response()`
///     2. send response body by using the `@http.ServerConnection` as `@io.Writer`
///     3. (optional) complete the response via `.end_response()`.
///         If `.end_response()` is not called, it will be called automatically
///         after `f` returns.
///
/// If `allow_failure` is `true` (`true` by default),
/// error raised by `f` will not crash the whole server.
/// In this case, `run_forever` will only terminate when cancelled externally.
/// Note that if `f` fails, the connection used by `f` will still get aborted.
///
/// If `max_connections` is present,
/// at most `max_connections` clients are allowed in parallel.
/// New clients will only get handled after a previous client terminates.
///
/// If `f` fails without closing the connection, 
/// `run_forever` will close each connection automatically.
/// If `f` manually closes the connection,
/// the connection will be dropped after `f` returns.
/// On error or cancellation, the server will be closed automatically.
pub async fn Server::run_forever(
  self : Server,
  f : async (Request, &@io.Reader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit {
  self.server.run_forever(allow_failure?, max_connections?, (conn, _) => {
    let conn = ServerConnection::new(conn, headers=self.headers)
    defer conn.close()
    for ;; {
      let request = conn.read_request()
      f(request, conn, conn)
      if conn.closed {
        break
      } else if conn.sender.mode is (WaitingBody | SendingBody) {
        conn.end_response()
      }
    }
  })
}

///|
/// Let the server enter "pass through" mode,
/// where the server serve as a TCP tunnel (maybe TLS encrypted) directly.
/// This is useful for handling the special `CONNECT` HTTP request and HTTP protcol upgrade.
///
/// In passthrough mode,
/// Read/write the server becomes direct read/write on the underlying connection,
/// and all API except `@io.Reader` and `@io.Writer` must not be used anymore.
///
/// When entering pass through mode,
/// the server must be in a clean state
/// (i.e. not in the middle of sending a response).
/// Unread data from the body of the last request will be discarded.
pub async fn ServerConnection::enter_passthrough_mode(self : Self) -> Unit {
  guard self.sender.mode is SendingHeader
  self.reader.enter_passthrough_mode()
  self.sender.enter_passthrough_mode()
}
