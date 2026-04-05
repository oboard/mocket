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
extern "C" fn init_global_job_object_ffi() -> Bool = "moonbitlang_async_init_global_job_objeect"

///|
#cfg(platform="windows")
let global_job_object_initialized : Ref[Bool] = Ref::new(false)

///|
#cfg(platform="windows")
fn init_global_job_object() -> Unit raise {
  guard global_job_object_initialized.val is false else {  }
  global_job_object_initialized.val = true
  if !init_global_job_object_ffi() {
    @os_error.check_errno("create global job object")
  }
}

///|
#cfg(platform="windows")
pub async fn spawn(
  command_line : @os_string.OsString,
  env~ : @os_string.OsString?,
  stdin~ : @fd_util.Fd,
  stdout~ : @fd_util.Fd,
  stderr~ : @fd_util.Fd,
  cwd~ : @os_string.OsString?,
  is_orphan~ : Bool,
  context~ : String,
) -> Int {
  init_global_job_object()
  perform_job_in_worker(
    Job::spawn(command_line, env, stdin, stdout, stderr, cwd, is_orphan~),
    context~,
  )
}

///|
#cfg(platform="windows")
#borrow(out)
extern "C" fn get_process_result(pid : Int, out : Ref[Int]) -> Int = "moonbitlang_async_get_process_result"

///|
#cfg(platform="windows")
pub async fn wait_pid(pid : Int, context~ : String) -> Int {
  let job = Job::wait_for_process(pid)
  perform_job_in_worker(job, context~, cancel=_ => {
    job.cancel_process_waiter()
    NeedWait
  })
  |> ignore
  let out = Ref::new(0)
  let ret = get_process_result(pid, out)
  if ret < 0 {
    @os_error.check_errno(context)
  }
  out.val
}
