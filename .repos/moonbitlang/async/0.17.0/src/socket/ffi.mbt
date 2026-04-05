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
extern "C" fn make_tcp_socket_ffi(family : AddrFamily) -> @fd_util.Fd = "moonbitlang_async_make_tcp_socket"

///|
#cfg(not(platform="windows"))
fn make_tcp_socket(family : AddrFamily, context~ : String) -> @fd_util.Fd raise {
  let sock = make_tcp_socket_ffi(family)
  if sock < 0 {
    @os_error.check_errno(context)
  }
  @fd_util.set_cloexec(sock, context~)
  sock
}

///|
#cfg(platform="windows")
fn make_tcp_socket(family : AddrFamily, context~ : String) -> @fd_util.Fd raise {
  let sock = make_tcp_socket_ffi(family)
  if !@fd_util.fd_is_valid(sock) {
    @os_error.check_errno(context)
  }
  sock
}

///|
extern "C" fn make_udp_socket_ffi(family : AddrFamily) -> @fd_util.Fd = "moonbitlang_async_make_udp_socket"

///|
#cfg(not(platform="windows"))
fn make_udp_socket(family : AddrFamily, context~ : String) -> @fd_util.Fd raise {
  let sock = make_udp_socket_ffi(family)
  if sock < 0 {
    @os_error.check_errno(context)
  }
  @fd_util.set_cloexec(sock, context~)
  sock
}

///|
#cfg(platform="windows")
fn make_udp_socket(family : AddrFamily, context~ : String) -> @fd_util.Fd raise {
  let sock = make_udp_socket_ffi(family)
  if !@fd_util.fd_is_valid(sock) {
    @os_error.check_errno(context)
  }
  sock
}

///|
extern "C" fn set_ipv6_only(sock : @fd_util.Fd, dual_stack : Bool) -> Int = "moonbitlang_async_set_ipv6_only"

///|
extern "C" fn listen_ffi(sock : @fd_util.Fd) -> Int = "moonbitlang_async_listen"

///|
#borrow(addr)
extern "C" fn connect_ffi(sock : @fd_util.Fd, addr : Addr) -> Int = "moonbitlang_async_udp_client_connect"

///|
extern "C" fn disable_nagle(sock : @fd_util.Fd) -> Int = "moonbitlang_async_disable_nagle"

///|
extern "C" fn allow_reuse_addr(sock : @fd_util.Fd) -> Int = "moonbitlang_async_allow_reuse_addr"

///|
extern "C" fn enable_keepalive_ffi(
  sock : @fd_util.Fd,
  keep_idle : Int,
  keep_count : Int,
  keep_intv : Int,
) -> Int = "moonbitlang_async_enable_keepalive"

///|
#borrow(addr_out)
extern "C" fn getsockname_ffi(sock : @fd_util.Fd, addr_out : Addr) -> Int = "moonbitlang_async_getsockname"

///|
fn getsockname(
  sock : @fd_util.Fd,
  family : AddrFamily,
  context~ : String,
) -> Addr raise {
  let addr = Addr::empty(family)
  if getsockname_ffi(sock, addr) < 0 {
    @os_error.check_errno(context)
  }
  addr
}

///|
#cfg(platform="windows")
#borrow(addr_out)
extern "C" fn getpeername_ffi(sock : @fd_util.Fd, addr_out : Addr) -> Int = "moonbitlang_async_getpeername"

///|
#cfg(platform="windows")
fn getpeername(
  sock : @fd_util.Fd,
  family : AddrFamily,
  context~ : String,
) -> Addr raise {
  let addr = Addr::empty(family)
  if getpeername_ffi(sock, addr) != 0 {
    @os_error.check_errno(context)
  }
  addr
}
