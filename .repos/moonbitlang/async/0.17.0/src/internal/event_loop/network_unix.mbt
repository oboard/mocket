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
#cfg(not(platform="windows"))
#borrow(buf, addr)
extern "C" fn recvfrom_ffi(
  fd : @fd_util.Fd,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
) -> Int = "moonbitlang_async_recvfrom"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::recvfrom(
  handle : IoHandle,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
  context~ : String,
) -> Int {
  @coroutine.check_cancellation()
  handle.prepare_read()
  let ret = recvfrom_ffi(handle.fd, buf, offset~, len~, addr~)
  if ret >= 0 {
    @coroutine.pause()
    return ret
  }
  let ret = if @os_error.is_nonblocking_io_error() {
    handle.wait_read()
    recvfrom_ffi(handle.fd, buf, offset~, len~, addr~)
  } else {
    ret
  }
  if ret < 0 {
    @os_error.check_errno(context)
  }
  ret
}

///|
#cfg(not(platform="windows"))
#borrow(buf, addr)
extern "C" fn sendto_ffi(
  fd : @fd_util.Fd,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
) -> Int = "moonbitlang_async_sendto"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::sendto(
  handle : IoHandle,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
  context~ : String,
) -> Int {
  @coroutine.check_cancellation()
  handle.prepare_write()
  let ret = sendto_ffi(handle.fd, buf, offset~, len~, addr~)
  if ret >= 0 {
    @coroutine.pause()
    return ret
  }
  let ret = if @os_error.is_nonblocking_io_error() {
    handle.wait_write()
    sendto_ffi(handle.fd, buf, offset~, len~, addr~)
  } else {
    ret
  }
  if ret < 0 {
    @os_error.check_errno(context)
  }
  ret
}

///|
#cfg(not(platform="windows"))
#borrow(addr)
extern "C" fn connect_ffi(sock : @fd_util.Fd, addr : Bytes) -> Int = "moonbitlang_async_connect"

///|
#cfg(not(platform="windows"))
extern "C" fn get_socket_err(sock : @fd_util.Fd) -> Int = "moonbitlang_async_getsockerr"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::connect(
  handle : IoHandle,
  addr : Bytes,
  context~ : String,
) -> Unit {
  @coroutine.check_cancellation()
  handle.prepare_write()
  if 0 == connect_ffi(handle.fd, addr) {
    return
  }
  if @os_error.is_nonblocking_io_error() {
    handle.wait_write()
    let err = get_socket_err(handle.fd)
    if err < 0 {
      @os_error.check_errno(context)
    } else if err > 0 {
      raise @os_error.OSError(err, context~)
    }
  } else {
    @os_error.check_errno(context)
  }
}

///|
#cfg(not(platform="windows"))
#borrow(addr_buf)
extern "C" fn accept_ffi(sock : @fd_util.Fd, addr_buf : Bytes) -> Int = "moonbitlang_async_accept"

///|
#cfg(not(platform="windows"))
pub async fn IoHandle::accept(
  handle : IoHandle,
  addr : Bytes,
  context~ : String,
) -> IoHandle {
  @coroutine.check_cancellation()
  handle.prepare_read()
  let conn = accept_ffi(handle.fd, addr)
  let conn = if conn >= 0 {
    conn
  } else if @os_error.is_nonblocking_io_error() {
    handle.wait_read()
    accept_ffi(handle.fd, addr)
  } else {
    conn
  }
  if conn < 0 {
    @os_error.check_errno(context)
  }
  IoHandle::from_fd(conn, kind=Socket)
}
