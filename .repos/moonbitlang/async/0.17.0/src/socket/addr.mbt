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
priv enum AddrFamily {
  IPv4 = 4
  IPv6 = 6
}

///|
/// IPv4 address + port number
#warnings("-unused_constructor")
struct Addr(Bytes) derive(Eq, Compare, Hash)

///|
pub extern "C" fn Addr::new(ip : UInt, port : Int) -> Addr = "moonbitlang_async_make_ip_addr"

///|
extern "C" fn Addr::empty(family : AddrFamily) -> Addr = "moonbitlang_async_make_empty_addr"

///|
#borrow(ip)
extern "C" fn Addr::new_ipv6(ip : FixedArray[Byte], port : Int) -> Addr = "moonbitlang_async_make_ipv6_addr"

///|
#borrow(addr)
pub extern "C" fn Addr::ip(addr : Addr) -> UInt = "moonbitlang_async_ip_addr_get_ip"

///|
#borrow(addr)
pub extern "C" fn Addr::port(addr : Addr) -> Int = "moonbitlang_async_ip_addr_get_port"

///|
#borrow(addr)
pub extern "C" fn Addr::is_ipv6(addr : Addr) -> Bool = "moonbitlang_async_addr_is_ipv6"

///|
fn Addr::family(self : Addr) -> AddrFamily {
  if self.is_ipv6() {
    IPv6
  } else {
    IPv4
  }
}

///|
#borrow(addr)
extern "C" fn Addr::get_ipv6_bytes(addr : Addr) -> @c_buffer.Buffer = "moonbitlang_async_addr_get_ipv6_bytes"

///|
#borrow(addr)
extern "C" fn Addr::is_ipv6_wildcard(addr : Addr) -> Bool = "moonbitlang_async_addr_is_ipv6_wildcard"

///|
pub impl Show for Addr with output(self, logger) {
  if self.is_ipv6() {
    // IPv6 address format
    logger.write_char('[')
    write_ipv6_str(self.get_ipv6_bytes(), logger)
    logger..write_char(']')..write_char(':').write_object(self.port())
  } else {
    // IPv4 address format
    let ip = self.ip()
    let port = self.port()
    logger
    ..write_object(ip >> 24)
    ..write_char('.')
    ..write_object((ip >> 16) & 255)
    ..write_char('.')
    ..write_object((ip >> 8) & 255)
    ..write_char('.')
    ..write_object(ip & 255)
    ..write_char(':')
    .write_object(port)
  }
}

///|
pub suberror InvalidAddr derive(Show, ToJson)

///|
/// Parse a string into IPv4 or IPv6 address, format should be `ip:port` for IPv4 or `[ip]:port` for IPv6
// TODO: faster implementation
pub fn Addr::parse(src : String) -> Addr raise InvalidAddr {
  if src.has_prefix("[") {
    let (ip_bytes, port, _, _) = try_parse_ipv6(src)
    Addr::new_ipv6(ip_bytes, port)
  } else {
    // IPv4 format: ip:port
    let (ip, port) = try_parse_ipv4(src) catch { _ => raise InvalidAddr }
    guard 0 <= port && port < 65536 else { raise InvalidAddr }
    Addr::new(ip, port)
  }
}

///|
using @event_loop {type AddrInfo}

///|
extern "C" fn AddrInfo::is_null(self : AddrInfo) -> Bool = "moonbitlang_async_addrinfo_is_null"

///|
/// Convert AddrInfo to Addr(support both IPv4 and IPv6)
extern "C" fn AddrInfo::to_addr(self : AddrInfo, port : Int) -> Addr = "moonbitlang_async_addrinfo_to_addr"

///|
extern "C" fn AddrInfo::next(self : AddrInfo) -> AddrInfo = "moonbitlang_async_addrinfo_get_next"

///|
#cfg(not(platfrom="windows"))
extern "C" fn AddrInfo::free(self : AddrInfo) = "freeaddrinfo"

///|
#cfg(platfrom="windows")
extern "C" fn AddrInfo::free(self : AddrInfo) = "FreeAddrInfoW"

///|
/// Error message from failure in resolving a network hostname.
/// The content of the error message is platfrom-dependent,
/// so users should never depend on it.
pub suberror ResolveHostnameError {
  ResolveHostnameError(String)
} derive(Show, ToJson)

///|
pub(all) enum IpProtocolPreference {
  OnlyV4
  OnlyV6
  FavorV4
  FavorV6
  NoPreference
} derive(Show)

///|
/// Resolve a IPv4 or IPv6 address by hostname.
///
/// By default, `Addr::resolve` return the first available address.
/// Preference on IPv4 v.s. IPv6 can be configured via `protocol`.
/// See `IPProtocolPreference` for available options.
pub async fn Addr::resolve(
  host : String,
  port~ : Int,
  protocol? : IpProtocolPreference = NoPreference,
) -> Addr {
  // TODO: Add option to prefer ipv6 or ipv4
  let context = "@socket.Addr::resolve()"
  let ai_root = match @event_loop.getaddrinfo(host, context~) {
    Ok(ai_root) => ai_root
    Err(msg) => raise ResolveHostnameError(msg)
  }
  defer ai_root.free()
  let first_addr = ai_root.to_addr(port)

  // search for address with preferred protocol
  match protocol {
    FavorV4 | OnlyV4 => {
      if !first_addr.is_ipv6() {
        return first_addr
      }
      for ai = ai_root.next(); !ai.is_null(); ai = ai.next() {
        let addr = ai.to_addr(port)
        if !addr.is_ipv6() {
          return addr
        }
      }
      if protocol is OnlyV4 {
        raise ResolveHostnameError("No available IPv4 address")
      } else {
        first_addr
      }
    }
    FavorV6 | OnlyV6 => {
      if first_addr.is_ipv6() {
        return first_addr
      }
      for ai = ai_root.next(); !ai.is_null(); ai = ai.next() {
        let addr = ai.to_addr(port)
        if addr.is_ipv6() {
          return addr
        }
      }
      if protocol is OnlyV6 {
        raise ResolveHostnameError("No available IPv6 address")
      } else {
        first_addr
      }
    }
    NoPreference => first_addr
  }
}
