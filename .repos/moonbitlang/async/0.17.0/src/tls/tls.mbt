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
pub suberror TlsError {
  TlsError(String)
} derive(Show, ToJson)

///|
pub suberror ConnectionClosed derive(Show, ToJson)

///|
/// Create a TLS client that read from write to `inner`.
/// `client` will block until TLS handshake to remote server completed.
///
/// If `verify` is `true` (`true` by default),
/// `client` will perform verification on server's certificate,
/// using the default verification setting of the OpenSSL library.
///
/// If `host` is present, it will be used to verify the peer's certificate.
///
/// If `host` is present and `sni` is `true` (`true` by default),
/// Server Name Indication (SNI) field of TLS will be set to `host`.
pub async fn[Inner : @io.Reader + @io.Writer] Tls::client(
  inner : Inner,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
) -> Tls {
  Tls::client_from_pair(inner, inner, verify~, host?, sni~)
}
