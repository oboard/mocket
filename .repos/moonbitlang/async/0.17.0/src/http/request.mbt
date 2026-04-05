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
pub(all) enum Protocol {
  Http
  Https
} derive(Show, Eq, Compare, Hash, ToJson)

///|
pub fn Protocol::default_port(p : Protocol) -> Int {
  match p {
    Http => 80
    Https => 443
  }
}

///|
pub suberror URIParseError {
  InvalidFormat
  UnsupportedProtocol(String)
} derive(Show, ToJson)

///|
fn resolve_url(uri : String) -> (Protocol, Int, String, String) raise {
  guard uri.find("://") is Some(protocol_len) else { raise InvalidFormat }
  let protocol = match uri[:protocol_len] {
    "http" => Http
    "https" => Https
    protocol => raise UnsupportedProtocol(protocol.to_string())
  }
  let uri = uri[protocol_len + 3:]
  let (host, path) = if uri.find("/") is Some(i) {
    (uri[:i].to_string(), uri[i:].to_string())
  } else {
    (uri.to_string(), "/")
  }
  let (host, port) = if host lexmatch? (host, ":" ("[0-9]+" as port_str)) {
    let port = @string.parse_int(port_str) catch { _ => raise InvalidFormat }
    guard port is (1..<65536) else { raise InvalidFormat }
    (host.to_string(), port)
  } else {
    (host, protocol.default_port())
  }
  let path = if path == "" { "/" } else { path }
  (protocol, port, host, path)
}

///|
async fn perform_request(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
) -> (Response, &@io.Data) {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  defer client.close()
  let response = client..request(meth, path)..write(body).end_request()
  (response, client.read_all())
}

///|
/// Perform a HTTP `GET` request to `uri`.
/// Supported protocols are `http://` and `https://`.
/// The HTTP response message and the whole response body will be returned.
///
/// `proxy`, if present, specifies the proxy to use for this request.
/// See `@http.Client::new` for more details.
/// `proxy` is not supported on JavaScript backend.
///
/// See `Client::request` for more details.
pub async fn get(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> (Response, &@io.Data) {
  perform_request(uri, Get, headers, body, proxy?)
}

///|
/// Similar to `get`, but performs a `PUT` request instead.
pub async fn put(
  uri : String,
  content : &@io.Data,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> (Response, &@io.Data) {
  perform_request(uri, Put, headers, content, proxy?)
}

///|
/// Similar to `get`, but performs a `POST` request instead.
pub async fn post(
  uri : String,
  content : &@io.Data,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> (Response, &@io.Data) {
  perform_request(uri, Post, headers, content, proxy?)
}

///|
/// Similar to `@http.get`, but allow reading response body streamingly.
/// A pair `(response, client)` will be returned,
/// where `response` is the response header from the server,
/// and `client` is the HTTP client that performs the request.
/// `client` can be used to read the content of response body via `@io.Reader`,
/// see `@http.Client` for more details.
///
/// Note that the returned client must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn get_stream(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> (Response, Client) {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  try {
    let response = client..request(Get, path)..write(body).end_request()
    (response, client)
  } catch {
    err => {
      client.close()
      raise err
    }
  }
}

///|
/// Similar to `@http.put`, but allow writing request body streamingly.
/// The return value `client` is the HTTP client that performs the request,
/// it can be used to write the content of request body via `@io.Writer`.
/// Notice that writing to `@http.Client` is buffered,
/// so if you need to send data to the server immediately, `.flush()` must be called.
/// After writing all the content, `.end_request()` must be called
/// to complete the request and obtain response from the server.
/// After that, the response body from the server can be obtained 
/// by using `client` as a `@io.Reader`. See `@http.Client` for more details.
///
/// Note that the returned `client` must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn put_stream(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> Client {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  try client.request(Put, path) catch {
    err => {
      client.close()
      raise err
    }
  } noraise {
    _ => client
  }
}

///|
/// Similar to `@http.post`, but allow writing request body streamingly.
/// The return value `client` is the HTTP client that performs the request,
/// it can be used to write the content of request body via `@io.Writer`.
/// Notice that writing to `@http.Client` is buffered,
/// so if you need to send data to the server immediately, `.flush()` must be called.
/// After writing all the content, `.end_request()` must be called
/// to complete the request and obtain response from the server.
/// After that, the response body from the server can be obtained 
/// by using `client` as a `@io.Reader`. See `@http.Client` for more details.
///
/// Note that the returned `client` must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn post_stream(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> Client {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  try client.request(Post, path) catch {
    err => {
      client.close()
      raise err
    }
  } noraise {
    _ => client
  }
}
