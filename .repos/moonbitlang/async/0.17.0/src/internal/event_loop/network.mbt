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
#external
pub type AddrInfo

///|
#cfg(not(platform="windows"))
extern "C" fn gai_strerror(code : Int) -> @c_buffer.Buffer = "gai_strerror"

///|
#cfg(not(platform="windows"))
fn gai_error_to_string(code : Int) -> String {
  @os_string.decode(gai_strerror(code))
}

///|
#cfg(platform="windows")
fn gai_error_to_string(code : Int) -> String {
  @os_error.errno_to_string(code)
}

///|
pub async fn getaddrinfo(
  host : StringView,
  context~ : String,
) -> Result[AddrInfo, String] {
  let host_bytes = @os_string.encode(host)
  let job = Job::getaddrinfo(host_bytes)
  let ret = perform_job_in_worker(job, cancel=_ => NoWait, context~) catch {
    @os_error.OSError(errno, context~) =>
      raise @os_error.OSError(errno, context="\{context}: \{host.escape()}")
    err => raise err
  }
  if ret != 0 {
    Err(gai_error_to_string(ret))
  } else {
    Ok(job.get_getaddrinfo_result())
  }
}

///|
pub async fn IoHandle::bind(
  handle : IoHandle,
  addr : Bytes,
  context~ : String,
) -> Unit {
  @coroutine.check_cancellation()
  ignore(perform_job_in_worker(Job::bind(handle.fd, addr), context~))
}
