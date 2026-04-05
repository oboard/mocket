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
#cfg(platform="windows")
extern "C" fn init_WSA_ffi() -> Int = "moonbitlang_async_init_WSA"

///|
#cfg(platform="windows")
extern "C" fn cleanup_WSA_ffi() -> Int = "moonbitlang_async_cleanup_WSA"

///|
#cfg(platform="windows")
pub async fn IoHandle::recvfrom(
  handle : IoHandle,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
  context~ : String,
) -> Int {
  @coroutine.check_cancellation()
  guard curr_loop.val is Some(evloop)
  guard !handle.reading
  handle.reading = true
  defer {
    handle.reading = false
  }
  let job_id = evloop.job_id
  evloop.job_id += 1
  let result = IoResult::for_socket_with_addr(
    job_id,
    buf.unsafe_reinterpret_as_bytes(),
    offset~,
    len~,
    flags=0,
    addr~,
  )
  defer result.free()
  handle.generic_read(job_id, result, context~)
}

///|
#cfg(platform="windows")
pub async fn IoHandle::sendto(
  handle : IoHandle,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
  addr~ : Bytes,
  context~ : String,
) -> Int {
  @coroutine.check_cancellation()
  guard curr_loop.val is Some(evloop)
  guard !handle.writing
  handle.writing = true
  defer {
    handle.writing = false
  }
  let job_id = evloop.job_id
  evloop.job_id += 1
  let result = IoResult::for_socket_with_addr(
    job_id,
    buf,
    offset~,
    len~,
    flags=0,
    addr~,
  )
  defer result.free()
  handle.generic_write(job_id, result, context~)
}

///|
#cfg(platform="windows")
extern "C" fn connect_ffi(sock : @fd_util.Fd, result : IoResult) -> Int = "moonbitlang_async_connect"

///|
#cfg(platform="windows")
extern "C" fn setup_connected_socket_ffi(sock : @fd_util.Fd) -> Int = "moonbitlang_async_setup_connected_socket"

///|
#cfg(platform="windows")
pub async fn IoHandle::connect(
  handle : IoHandle,
  addr : Bytes,
  context~ : String,
) -> Unit {
  @coroutine.check_cancellation()
  guard curr_loop.val is Some(evloop)
  guard !handle.writing
  handle.writing = true
  defer {
    handle.writing = false
  }
  let job_id = evloop.job_id
  evloop.job_id += 1
  let result = IoResult::for_connect(job_id, addr)
  defer result.free()
  if 0 == connect_ffi(handle.fd, result) {
    if !@os_error.is_nonblocking_io_error() {
      @os_error.check_errno(context)
    }
    evloop.wait_for_io_result(job_id, result, handle.fd, context~)
    ignore(result.status(handle.fd, context~))
  }
  if setup_connected_socket_ffi(handle.fd) < 0 {
    @os_error.check_errno(context)
  }
}

///|
#cfg(platform="windows")
extern "C" fn accept_ffi(
  server_sock : @fd_util.Fd,
  conn_sock : @fd_util.Fd,
  result : IoResult,
) -> Int = "moonbitlang_async_accept"

///|
#cfg(platform="windows")
extern "C" fn setup_accepted_socket_ffi(
  listen_sock : @fd_util.Fd,
  accept_sock : @fd_util.Fd,
) -> Int = "moonbitlang_async_setup_accepted_socket"

///|
#cfg(platform="windows")
pub async fn IoHandle::accept(
  handle : IoHandle,
  conn_sock : @fd_util.Fd,
  context~ : String,
) -> IoHandle {
  @coroutine.check_cancellation()
  guard curr_loop.val is Some(evloop)
  guard !handle.reading
  handle.reading = true
  defer {
    handle.reading = false
  }
  let job_id = evloop.job_id
  evloop.job_id += 1
  let result = IoResult::for_accept(job_id)
  defer result.free()
  if 0 == accept_ffi(handle.fd, conn_sock, result) {
    if !@os_error.is_nonblocking_io_error() {
      @os_error.check_errno(context)
    }
    evloop.wait_for_io_result(job_id, result, handle.fd, context~)
    ignore(result.status(handle.fd, context~))
  }
  if setup_accepted_socket_ffi(handle.fd, conn_sock) < 0 {
    @os_error.check_errno(context)
  }
  IoHandle::from_fd(conn_sock, kind=Socket)
}
