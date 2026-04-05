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
/// A UDP client "connected" to a remote UDP server.
///
/// UDP is a connectionless protocol, here "connected" means
/// the client always send packet to and receive packet from
/// the specified remote server.
pub struct UdpClient {
  /// Local address of the client
  addr : Addr
  priv io : @event_loop.IoHandle

  fn new(server : Addr) -> UdpClient raise
}

///|
/// Create a new UDP client connected to server at `addr`.
/// The client always send packet to and receive packet from
/// the specified remote server.
pub fn UdpClient::new(server : Addr) -> UdpClient raise {
  let context = "@socket.UdpClient::new()"
  let family = server.family()
  let sock = make_udp_socket(family, context~)
  try {
    if 0 != connect_ffi(sock, server) {
      @os_error.check_errno(context)
    }
  } catch {
    err => {
      @fd_util.close(sock, kind=Socket, context~)
      raise err
    }
  }
  let addr = getsockname(sock, family, context~)
  { io: @event_loop.IoHandle::from_fd(sock, kind=Socket), addr }
}

///|
pub fn UdpClient::close(self : UdpClient) -> Unit {
  self.io.close()
}

///|
pub fn UdpClient::fd(self : UdpClient) -> @fd_util.Fd {
  self.io.fd()
}

///|
/// Get the local address of a UDP client.
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(self : UdpClient) -> Addr {
  self.addr
}

///|
/// A UDP server bound to a listen address and receive packets from clients.
pub struct UdpServer {
  addr : Addr
  priv io : @event_loop.IoHandle

  async fn new(addr : Addr, dual_stack? : Bool) -> UdpServer
}

///|
pub fn UdpServer::close(self : UdpServer) -> Unit {
  self.io.close()
}

///|
pub fn UdpServer::fd(self : UdpClient) -> @fd_util.Fd {
  self.io.fd()
}

///|
/// Create a UDP server listening at `addr`.
///
/// If `addr` is the IPv6 wildcard address `[::]`
/// and `dual_stack` is `true` (`true` by default),
/// the server will work in dual stack mode,
/// receiving packets from both IPv4 peers and IPv6 peers.
/// The address of IPv4 peers are represented via IPv4-mapped IPv6 address.
///
/// If `addr` is not `[::]`, `dual_stack` is ignored.
///
/// If the port of `addr` is zero, the server will be bound to a random port,
/// assigned by the operating system.
/// The actual listen address can be retrieved via `.addr()`.
pub async fn UdpServer::new(
  addr : Addr,
  dual_stack? : Bool = true,
) -> UdpServer {
  let context = "@socket.UdpServer::new()"
  let family = addr.family()
  let sock = make_udp_socket(family, context~)
  let io = @event_loop.IoHandle::from_fd(sock, kind=Socket)
  try {
    if addr.is_ipv6() && addr.is_ipv6_wildcard() {
      if 0 != set_ipv6_only(sock, !dual_stack) {
        @os_error.check_errno(context)
      }
    }
    io.bind(addr.0, context~)
    // If `addr` specifies zero as the listen port,
    // the OS will assign a random port for us,
    // in this case, we need to retrieve the actual port via `getsockname`.
    let addr = getsockname(sock, family, context~)
    { io, addr }
  } catch {
    err => {
      @fd_util.close(sock, kind=Socket, context~)
      raise err
    }
  }
}

///|
/// Get the listen address of a UDP server.
#deprecated("use `.addr` instead")
pub fn UdpServer::addr(self : UdpServer) -> Addr {
  self.addr
}

///|
/// Receive packet from a UDP client.
/// For `udp.recv(buf, offset~, max_len~)`,
/// at most `max_len` bytes of data will be written to `buf`, starting from `offset`.
/// The number of received bytes will be returned.
///
/// UDP is a datagram based protocol,
/// and `recv` will always receive exactly one UDP packet.
/// If the buffer is smaller than the received packet,
/// the rest of the packet will be lost.
///
/// At most one task can read from a UDP client at any time.
/// To allow multiple reader,
/// use a worker task for reading and use `@async.Queue` to distribute the data.
pub async fn UdpClient::recv(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int = 0,
  max_len? : Int = buf.length() - offset,
) -> Int {
  self.io.read(buf, offset~, len=max_len, context="@socket.UdpClient::recv")
}

///|
/// Receive packet from a UDP server, and obtain the source address of the packet.
/// For `udp.recvfrom(buf, offset~, max_len~)`,
/// at most `max_len` bytes of data will be written to `buf`, starting from `offset`.
/// The number of received bytes and the source address of the packet will be returned.
///
/// UDP is a datagram based protocol,
/// and `recv` will always receive exactly one UDP packet.
/// If the buffer is smaller than the received packet,
/// the rest of the packet will be lost.
///
/// At most one task can read from a UDP server at any time.
/// To allow multiple reader,
/// use a worker task for reading and use `@async.Queue` to distribute the data.
pub async fn UdpServer::recvfrom(
  self : UdpServer,
  buf : FixedArray[Byte],
  offset? : Int = 0,
  max_len? : Int = buf.length() - offset,
) -> (Int, Addr) {
  // Create a big enough Addr to hold both IPv4 and IPv6 address
  let addr = Addr::empty(self.addr.family())
  let n_read = self.io.recvfrom(
    buf,
    offset~,
    len=max_len,
    addr=addr.0,
    context="@socket.UdpServer::recvfrom",
  )
  (n_read, addr)
}

///|
/// Send data through a UDP client.
///
/// UDP is a datagram based protocol, every call of `send` will send exactly one packet.
///
/// At most one task can write to a UDP client at any time.
/// To allow multiple writers,
/// use a worker task for reading and use `@async.Queue` to gather the data.
pub async fn UdpClient::send(
  self : UdpClient,
  buf : Bytes,
  offset? : Int = 0,
  len? : Int = buf.length() - offset,
) -> Unit {
  self.io.write(buf, offset~, len~, context="@socket.UdpClient::send") |> ignore
}

///|
/// Send a packet to `addr` through a UDP server.
///
/// UDP is a datagram based protocol, every call of `send` will send exactly one packet.
///
/// At most one task can write to a UDP server at any time.
/// To allow multiple writers,
/// use a worker task for reading and use `@async.Queue` to gather the data.
pub async fn UdpServer::sendto(
  self : UdpServer,
  buf : Bytes,
  addr : Addr,
  offset? : Int = 0,
  len? : Int = buf.length() - offset,
) -> Unit {
  self.io.sendto(
    buf,
    offset~,
    len~,
    addr=addr.0,
    context="@socket.UdpServer::sendto",
  )
  |> ignore
}
