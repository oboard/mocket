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
/// A Tcp connection
pub struct Tcp {
  /// The local address of a TCP connection
  addr : Addr
  priv io : @event_loop.IoHandle
  priv read_buf : @io.ReaderBuffer
}

///|
pub fn Tcp::close(self : Tcp) -> Unit {
  self.io.close()
}

///|
pub fn Tcp::fd(self : Tcp) -> @fd_util.Fd {
  self.io.fd()
}

///|
pub struct TcpServer {
  /// The actual listen address of the server
  addr : Addr
  priv io : @event_loop.IoHandle

  async fn new(addr : Addr, dual_stack? : Bool, reuse_addr? : Bool) -> TcpServer
}

///|
/// Create a TCP server that is bound to `addr`,
/// listening for incoming connections.
///
/// If `addr` is the IPv6 wildcard address `[::]`
/// and `dual_stack` is `true` (`true` by default),
/// the server will work in dual stack mode,
/// accepting connections from both IPv4 clients and IPv6 clients.
/// The address of IPv4 clients are represented via IPv4-mapped IPv6 address.
///
/// If `addr` is not `[::]`, `dual_stack` is ignored.
///
/// If the port of `addr` is zero, the server will be bound to a random port,
/// assigned by the operating system.
/// The actual listen address can be retrieved via `.addr()`.
///
/// If `reuse_addr` is `true` (`false` by default),
/// the `SO_REUSEADDR` option will be enabled on the server,
/// allowing in currently-in-use socket address
/// (as long as there is no one else currently listening on the same address).
/// This is useful for avoiding "address already in use" error while testing.
/// WARNING: enabling `reuse_addr` on production is unsafe,
/// packets from the previous listener of the address may be accidentally received.
pub async fn TcpServer::new(
  addr : Addr,
  dual_stack? : Bool = true,
  reuse_addr? : Bool = false,
) -> TcpServer {
  let context = "@socket.TcpServer::new()"
  let family = addr.family()
  let sock = make_tcp_socket(family, context~)
  let io = @event_loop.IoHandle::from_fd(sock, kind=Socket)
  try {
    if addr.is_ipv6() && addr.is_ipv6_wildcard() {
      if 0 != set_ipv6_only(sock, !dual_stack) {
        @os_error.check_errno(context)
      }
    }
    if reuse_addr {
      guard allow_reuse_addr(sock) >= 0 else { @os_error.check_errno(context) }
    }
    io.bind(addr.0, context~)
    if 0 != listen_ffi(sock) {
      @os_error.check_errno(context)
    }
    // If `addr` specifies zero as the listen port,
    // the OS will assign a random port for us,
    // in this case, we need to retrieve the actual port via `getsockname`.
    let addr = getsockname(sock, family, context~)
    { io, addr }
  } catch {
    err => {
      io.close()
      raise err
    }
  }
}

///|
/// Get the address the server is listening on
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(server : TcpServer) -> Addr {
  server.addr
}

///|
/// Start the main loop of a TCP server,
/// keep listening for new connections
/// and handle connections using the callback `f`.
/// `f` will be supplied the new connection and the address of the client.
///
/// The client connection will be closed automatically after `f` exits,
/// so `f` must not close the client connection.
/// The server will be automatically closed if `run_forever` fails.
///
/// If `allow_failure` is `true` (`true` by default),
/// failure in `f` will be silently ignored.
///
/// If `max_connections` is present,
/// at most `max_connections` clients are allowed in parallel.
/// New clients will only get handled after a previous client terminates.
pub async fn TcpServer::run_forever(
  self : TcpServer,
  f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool = true,
  max_connections? : Int,
) -> Unit {
  defer self.close()
  let conn_limit = match max_connections {
    None => None
    Some(n) => Some(@async.Semaphore::new(n))
  }
  @async.with_task_group(group => {
    for ;; {
      let (conn, addr) = self.accept()
      if conn_limit is Some(limit) {
        limit.acquire()
      }
      group.spawn_bg(allow_failure~, () => {
        defer conn.close()
        if conn_limit is Some(limit) {
          defer limit.release()
          f(conn, addr)
        } else {
          f(conn, addr)
        }
      })
    }
  })
}

///|
pub fn TcpServer::close(self : TcpServer) -> Unit {
  self.io.close()
}

///|
pub fn TcpServer::fd(self : TcpServer) -> @fd_util.Fd {
  self.io.fd()
}

///|
/// Accept a new connection on a listening TCP server.
/// The accepted connection will be returned together with the address of peer.
#cfg(not(platform="windows"))
pub async fn TcpServer::accept(self : TcpServer) -> (Tcp, Addr) {
  // Create a big enough Addr to hold both IPv4 and IPv6 address
  let addr = Addr::empty(self.addr.family())
  let conn = self.io.accept(addr.0, context="@socket.TcpServer::accept")
  try {
    if disable_nagle(conn.fd()) < 0 {
      @os_error.check_errno("@socket.TcpServer::accept(): set TCP_NODELAY")
    }
    @fd_util.set_cloexec(conn.fd(), context="@socket.TcpServer::accept()")
  } catch {
    err => {
      conn.close()
      raise err
    }
  }
  // The local address of a server connection is the same as the listen address
  ({ io: conn, addr: self.addr, read_buf: @io.ReaderBuffer::new() }, addr)
}

///|
/// Accept a new connection on a listening TCP server.
/// The accepted connection will be returned together with the address of peer.
#cfg(platform="windows")
pub async fn TcpServer::accept(self : TcpServer) -> (Tcp, Addr) {
  let context = "@socket.TcpServer::accept()"
  let family = self.addr.family()
  let conn_sock = make_tcp_socket(family, context~)
  let conn = self.io.accept(conn_sock, context~)
  if disable_nagle(conn_sock) < 0 {
    @fd_util.close(conn_sock, kind=Socket, context~)
    @os_error.check_errno("@socket.TcpServer::accept(): set TCP_NODELAY")
  }
  let addr = getpeername(conn_sock, self.addr.family(), context~)
  // The local address of a server connection is the same as the listen address
  ({ io: conn, addr: self.addr, read_buf: @io.ReaderBuffer::new() }, addr)
}

///|
/// Enable TCP keep alive on the socket.
///
/// `idle_before_keep_alive` is the duration of idle time in seconds to wait
/// before sending the first keep alive probe.
///
/// `keep_alive_count` is the number of keep alive probe to try
/// before closing the connection.
///
/// `keep_alive_interval` is the time in seconds between two keep alive probes.
pub fn Tcp::enable_keepalive(
  self : Tcp,
  idle_before_keep_alive? : Int = -1,
  keep_alive_count? : Int = -1,
  keep_alive_interval? : Int = -1,
) -> Unit raise {
  let ret = enable_keepalive_ffi(
    self.io.fd(),
    idle_before_keep_alive,
    keep_alive_count,
    keep_alive_interval,
  )
  if ret < 0 {
    @os_error.check_errno("@socket.Tcp::enable_keepalive()")
  }
}

///|
/// Make connection to a remote address using `connect(2)` system call.
pub async fn Tcp::connect(addr : Addr) -> Tcp {
  let context = "@socket.Tcp::connect()"
  let family = addr.family()
  let sock = make_tcp_socket(family, context~)
  let conn = @event_loop.IoHandle::from_fd(sock, kind=Socket)
  try {
    if disable_nagle(sock) < 0 {
      @os_error.check_errno("@socket.Tcp::connect(): set TCP_NODELAY")
    }
    conn.connect(addr.0, context~)
  } catch {
    err => {
      conn.close()
      raise err
    }
  }
  let addr = getsockname(sock, family, context~)
  { io: conn, addr, read_buf: @io.ReaderBuffer::new() }
}

///|
/// Get the local address of a TCP connection.
pub fn Tcp::addr(sock : Tcp) -> Addr {
  sock.addr
}

///|
/// Receive data from a TCP connection.
/// For `tcp.recv(buf, offset~, max_len~)`,
/// at most `max_len` bytes of data will be written to `buf`, starting from `offset`.
/// The number of received bytes will be returned.
///
/// At most one task can read from a TCP socket at any time.
/// To allow multiple reader,
/// use a worker task for reading and use `@async.Queue` to distribute the data.
pub impl @io.Reader for Tcp with _direct_read(self, buf, offset~, max_len~) {
  self.io.read(buf, offset~, len=max_len, context="@socket.Tcp::read()")
}

///|
pub impl @io.Reader for Tcp with _get_internal_buffer(self) {
  self.read_buf
}

///|
pub impl @io.Writer for Tcp with write_once(self, buf, offset~, len~) {
  self.io.write(buf, offset~, len~, context="@socket.Tcp::write()")
}
