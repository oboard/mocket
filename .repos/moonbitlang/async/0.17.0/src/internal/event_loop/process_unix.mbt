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
pub async fn spawn(
  path : @os_string.OsString,
  args : FixedArray[@os_string.OsString?],
  env~ : FixedArray[@os_string.OsString?],
  stdin~ : @fd_util.Fd,
  stdout~ : @fd_util.Fd,
  stderr~ : @fd_util.Fd,
  cwd~ : @os_string.OsString?,
  context~ : String,
) -> Int {
  perform_job_in_worker(
    Job::spawn(path, args, env, stdin, stdout, stderr, cwd),
    context~,
  )
}

///|
#cfg(not(platform="windows"))
#borrow(out)
extern "C" fn get_process_result(pid : Int, out : Ref[Int]) -> Int = "moonbitlang_async_get_process_result"

///|
#cfg(not(platform="windows"))
pub async fn wait_pid(pid : Int, context~ : String) -> Int {
  guard curr_loop.val is Some(evloop)
  guard support_wait_pid_via_poll else {
    // pidfd not available, fall back to blocking waitpid in worker thread.
    // The worker reaps the child and stores the exit code in job.ret(),
    // so return it here to avoid a second waitpid in get_process_result.
    let job = Job::wait_for_process(pid)
    let exit_code = perform_job_in_worker(job, context~, cancel=job_id => {
      evloop.cancel_job_in_worker(job_id, context~)
    })
    exit_code
  }
  match evloop.poll.register_pid(pid) {
    Running(alt_id) => {
      guard evloop.pids.get(alt_id) is None
      evloop.pids[alt_id] = @coroutine.current_coroutine()
      defer {
        evloop.pids.remove(alt_id)
        evloop.poll.remove_pid(alt_id)
      }
      @coroutine.suspend()
    }
    Stopped => ()
  }
  let out = Ref::new(0)
  let ret = get_process_result(pid, out)
  if ret < 0 {
    @os_error.check_errno(context)
  }
  out.val
}
