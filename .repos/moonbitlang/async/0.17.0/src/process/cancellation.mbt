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
extern "C" fn terminate_process(pid : Int) = "moonbitlang_async_terminate_process"

///|
extern "C" fn kill_process(pid : Int) = "moonbitlang_async_kill_process"

///|
/// A handler function used to stop spawned process on cancellation.
/// The function receive the PID of the process as input.
pub(all) struct CancellationHandler(async (Int) -> Unit)

///|
/// A process cancellation handler that first try to gracefully stop the process,
/// and if the process is still running after `timeout` milliseconds,
/// forcefully stop the process.
///
/// Graceful process termination is implemented via `SIGTERM` on POSIX-like systems,
/// and `CTRL_BREAK_EVENT` on Windows.
pub fn graceful_cancel(timeout~ : Int) -> CancellationHandler {
  pid => {
    terminate_process(pid)
    @async.sleep(timeout)
    kill_process(pid)
  }
}

///|
/// A process cancellation handler that forcefully stop the process.
/// Implemented via `SIGKILL` on POSIX-like systems and `TerminateProcess` on Windows.
pub fn hard_cancel() -> CancellationHandler {
  pid => kill_process(pid)
}
