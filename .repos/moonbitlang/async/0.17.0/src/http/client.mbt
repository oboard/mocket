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
priv enum ClientTransport {
  Plain(@socket.Tcp)
  Proxy(Client)
}

///|
/// Simple HTTP client which connect to a remote host via TCP
pub struct Client {
  priv reader : Reader
  priv transport : ClientTransport
  priv tls : @tls.Tls?
  priv sender : Sender
  priv mut request_method : RequestMethod?

  async fn new(
    uri : String,
    headers? : Map[String, String],
    proxy? : Client,
  ) -> Client
}

///|
/// Error raised when the proxy responded with a non-2XX response code
pub suberror ProxyError {
  ProxyError(Response)
} derive(Show, ToJson)

///|
async fn Client::connect(
  host : String,
  headers? : Map[String, String] = {},
  protocol? : Protocol = Https,
  port? : Int = protocol.default_port(),
  proxy? : Client,
) -> Client {
  let transport = if proxy is Some(proxy) {
    let path = "\{host}:\{port}"
    try {
      let response = proxy..request(Connect, path).end_request()
      guard response.code is (200..<300) else { raise ProxyError(response) }
      proxy..skip_response_body().enter_passthrough_mode()
    } catch {
      err => {
        proxy.close()
        raise err
      }
    }
    Proxy(proxy)
  } else {
    Plain(@socket.Tcp::connect_to_host(host, port~))
  }
  headers["Host"] = host
  let (tls, reader, sender) = match (protocol, transport) {
    (Http, Plain(conn)) =>
      (None, Reader::new(conn), Sender::new(conn, headers~))
    (Https, Plain(conn)) => {
      let tls = @tls.Tls::client(conn, host~) catch {
        err => {
          transport.close()
          raise err
        }
      }
      (Some(tls), Reader::new(tls), Sender::new(tls, headers~))
    }
    (Http, Proxy(proxy)) =>
      (None, Reader::new(proxy), Sender::new(proxy, headers~))
    (Https, Proxy(proxy)) => {
      let tls = @tls.Tls::client(proxy, host~) catch {
        err => {
          transport.close()
          raise err
        }
      }
      (Some(tls), Reader::new(tls), Sender::new(tls, headers~))
    }
  }
  { transport, tls, reader, sender, request_method: None }
}

///|
/// Create a new HTTP client by connecting to a remote host.
/// Host should be specified via `protocol://host[:port]`,
/// where `protocol` is one of `http` or `https`.
/// If `protocol` is `https`, a TLS connection will be established,
/// and the certificate of the remote peer will be verified.
///
/// `headers` can be used to specify persistent headers for the client,
/// i.e. all requests made from this client will share these headers.
/// The ownership of `headers` will be transferred to the new client,
/// so `headers` should not be used by the caller later.
/// The following headers is automatically set,
/// and must not be specified in `headers`:
///
/// - Host
/// - Content-Length, Transfer-Encoding
///
/// If `proxy` is present, it should be another HTTP client in a clean state.
/// The new client will send a `CONNECT` request via the proxy client
/// and try to establish a tunnel via the proxy client.
/// All subsequent requests made by the new client will go through the proxy tunnel.
/// The ownership of the proxy client is transferred to the new client,
/// so it must not be used nor closed anymore by the caller.
/// Using another HTTP client as proxy allows advanced features such as
/// proxy authentication and https `CONNECT` proxy.
pub async fn Client::new(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> Client {
  let (protocol, port, host, path) = resolve_url(uri)
  guard path is "/" else { raise InvalidFormat }
  Client::connect(host, protocol~, port~, headers~, proxy?)
}

///|
fn ClientTransport::close(self : ClientTransport) -> Unit {
  match self {
    Plain(conn) => conn.close()
    Proxy(proxy) => proxy.close()
  }
}

///|
/// Close a HTTP client and release underlying resource.
/// In particular close the underlying TCP connection.
/// This function is idempotent: it is safe to call `.close()` multiple times,
/// only the first `.close()` call takes effect.
pub fn Client::close(self : Client) -> Unit {
  if self.tls is Some(tls) {
    tls.close()
  }
  self.transport.close()
}

///|
pub impl @io.Reader for Client with _direct_read(self, buf, offset~, max_len~) {
  self.reader._direct_read(buf, offset~, max_len~)
}

///|
pub impl @io.Reader for Client with _get_internal_buffer(self) {
  self.reader._get_internal_buffer()
}

///|
/// Write data to the body of the request currently being sent.
/// Must be called after `send_request`.
/// `end_request` must be called after all content of response body has been sent.
///
/// Writing to `@http.Client` MAY be buffered,
/// call `flush` manually to ensure data is delivered to the remote peer.
pub impl @io.Writer for Client with write_once(self, buf, offset~, len~) {
  guard !(self.sender.mode is SendingHeader)
  self.sender.write_once(buf, offset~, len~)
}

///|
pub impl @io.Writer for Client with write_reader(self, reader) {
  guard !(self.sender.mode is SendingHeader)
  self.sender.write_reader(reader)
}

///|
/// Flush buffered data in the request body being sent, if any.
pub async fn Client::flush(self : Client) -> Unit {
  self.sender.flush()
}

///|
/// End the body of the request currently being sent,
/// and obtain response from the server.
/// Should be called immediately after request body is fully sent.
///
/// Only the header of the response will be received and returned,
/// the body of the response can be extracted by using `Client` as a `@io.Reader`.
///
/// If the body of the last response is still not consumed,
/// it will be discarded.
pub async fn Client::end_request(self : Client) -> Response {
  self.sender.end_body()
  self.reader.skip_body()
  let response = self.reader.read_response(request_method=self.request_method)
  self.request_method = None
  response
}

///|
/// Send a HTTP request to the server.
/// Only the header of the request will be sent,
/// request body can be sent by using `Client` as a `@io.Writer`.
/// Once request body has been sent,
/// `end_request` must be called to complete the request and obtain response from the server.
///
/// After performing a request,
/// the next request MUST NOT be made before the request is completed via `end_request`.
///
/// In addition to headers in `Client::connect`,
/// extra HTTP headers can be passed via `extra_headers`.
/// The following headers is automatically set by `request`,
/// and must not be specified in `extra_headers`:
///
/// - Host
/// - Content-Length, Transfer-Encoding
pub async fn Client::request(
  self : Client,
  meth : RequestMethod,
  path : String,
  extra_headers? : Map[String, String] = {},
) -> Unit {
  self.sender.send_request(meth, path, extra_headers~)
  self.request_method = Some(meth)
}

///|
/// Skip the body of the response currently being produced,
/// so that the next request can be made.
pub async fn Client::skip_response_body(self : Client) -> Unit {
  self.reader.skip_body()
}

///|
/// Perform a `GET` request to the server, see `Client::request` for more details.
pub async fn Client::get(
  self : Client,
  path : String,
  extra_headers? : Map[String, String] = {},
  body? : &@io.Data,
) -> Response {
  self.request(Get, path, extra_headers~)
  if body is Some(body) {
    self.write(body)
  }
  self.end_request()
}

///|
/// Perform a `PUT` request to the server, see `Client::request` for more details.
pub async fn Client::put(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String] = {},
) -> Response {
  self..request(Put, path, extra_headers~)..write(body).end_request()
}

///|
/// Perform a `POST` request to the server, see `Client::request` for more details.
pub async fn Client::post(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String] = {},
) -> Response {
  self..request(Post, path, extra_headers~)..write(body).end_request()
}

///|
/// Let the client enter "pass through" mode,
/// where the client serve as a TCP tunnel (maybe TLS encrypted) directly.
/// This is useful for the special `CONNECT` HTTP request and HTTP protocol upgrade.
///
/// In passthrough mode,
/// Read/write the client becomes direct read/write on the underlying connection,
/// and all API except `@io.Reader` and `@io.Writer` must not be used anymore.
///
/// When entering pass through mode,
/// the client must be in a clean state
/// (i.e. not in the middle of sending a request).
/// Unread data from the body of the last response will be discarded.
pub async fn Client::enter_passthrough_mode(self : Client) -> Unit {
  guard self.sender.mode is SendingHeader
  self.reader.enter_passthrough_mode()
  self.sender.enter_passthrough_mode()
}
