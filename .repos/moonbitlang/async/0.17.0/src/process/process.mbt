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
/// Execute a system process with command `cmd`,
/// and provide `args` as extra arguments to `cmd.
/// Both `cmd` and elements of `args` are encoded using UTF8.
/// The process ID of the spawned process will be returned.
///
/// The spawned process would be *orphan*, meaning that it will
/// keep running until completion or explicitly terminated,
/// even if the task that calls `spawn_orphan` is cancelled.
/// Users are recommended to use `@process.run` whenever possible,
/// because `@process.run` has better structured concurrency integration.
/// `spawn_orphan` should only be used when:
///
/// - the process is intended to be orphan,
///   i.e. keep running after parent process terminates
/// - operations on the process ID is needed, such as sending signals to the child process
///
/// The meaning of the arguments is the same as `@process.run`,
/// see `@process.run` for more details.
pub async fn spawn_orphan(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> Int {
  raw_spawn(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout~,
    stderr~,
    cwd~,
    is_orphan=true,
    context="@process.spawn_orphan()",
  )
}

///|
/// Wait for the process with specfic ID to terminate,
/// and return the exit code of the process.
pub async fn wait_pid(pid : Int) -> Int {
  let context = "@process.wait_pid()"
  @event_loop.wait_pid(pid, context~)
}

///|
/// Execute a system process with command `cmd`,
/// and provide `args` as extra arguments to `cmd.
/// Both `cmd` and elements of `args` are encoded using UTF8.
///
/// `run` will block until the new process terminates,
/// and returns the exit status of the process.
/// To run the process in background, use `@async.spawn` or `@async.spawn_bg`.
///
/// If `inherit_env` is `true` (`true` by default),
/// the new process will inherit environment variables of current process.
///
/// `extra_env`, if present, will set extra environment variables for the new process
/// (in addition to those inherited ones, if `inherit_env` is `true`).
/// Keys and values of `extra_env` are encoded using UTF8.
///
/// The standard IO of the new process will be redirected to
/// `stdin`, stdout` and  stderr`, if set.
/// Standard IO channel can be redirected to one of the following:
///
/// - a temporary pipe created via `read_from_process` or `write_to_process`,
///   which can be used to read from/write to the process directly
/// - a file on the filesystem, via `redirect_to_file` or `redirect_from_file`
/// - an existing `@pipe.PipeRead` or `@pipe.PipeWrite`,
///   for example redirecting standard error to standard out.
///
/// Note than when passing an existing pipe to the process,
/// the ownership of the pipe is *NOT* transferred.
/// So the caller should still close the channel manually when apporiate.
///
/// If `cwd` is present, the spawned command will be executed
/// in the directory specified by `cwd`.
///
/// If current task is cancelled while blocking,
/// `cancel_handler` will be used to automatically stop the process.
/// `@process.run` will not return until the process terminates, even if cancelled.
/// The default value of `cancel_handler` is `graceful_cancel(timeout=5000)`
/// (First try to gracefully terminate the process, and if the process is still running
/// after five seconds, terminate it forcefully).
///
/// If `cancel_handler` is still running after the process terminates,
/// it will be cancelled.
pub async fn run(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
) -> Int {
  let context = "@process.run()"
  let pid = raw_spawn(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout~,
    stderr~,
    cwd~,
    is_orphan=false,
    context~,
  )
  @event_loop.wait_pid(pid, context~) catch {
    _ if @coroutine.is_being_cancelled() =>
      @async.protect_from_cancel(() => {
        @async.with_task_group(group => {
          group.spawn_bg(no_wait=true, () => cancel_handler(pid))
          @event_loop.wait_pid(pid, context~)
        })
      })
    err => raise err
  }
}

///|
/// A handle to a spawned process
pub struct Process {
  pid : Int
  priv result : @async.Task[Int]
}

///|
/// Wait for a process to terminate, return the exit code of the process
pub async fn Process::wait(self : Process) -> Int {
  self.result.wait()
}

///|
/// If the process already terminated, return its exit code.
/// If the process is still running, return `None`.
pub fn Process::try_wait(self : Process) -> Int? raise {
  self.result.try_wait()
}

///|
/// Cancel a child process.
/// The method of cancellation is determined by the `cancel_handler` parameter of `@process.spawn`.
/// Notice that after `.cancel()` is called,
/// if may take a while before the child process actually terminates.
/// Use `.wait()` to wait for actual termination of the child process.
pub fn Process::cancel(self : Process) -> Unit {
  self.result.cancel()
}

///|
/// Spawn a child process inside a task group.
/// If `no_wait` is `false` (`fales` by default),
/// the task group will only exit when the child process terminates.
/// If `no_wait` is `true`, the child process will be terminated automatically
/// when the task group terminates.
///
/// A `Process` object will be returned,
/// users can retrieve the PID of the spawned process via `.pid`,
/// or wait for the process to terminate via `.wait()`/`.try_wait()`.
///
/// All arguments except `group` and `no_wait` have the same meaning as `@process.run`,
/// see `@process.run` for more details.
pub async fn[X] spawn(
  group : @async.TaskGroup[X],
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
) -> Process {
  let context = "@process.spawn()"
  let pid = raw_spawn(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout~,
    stderr~,
    cwd~,
    is_orphan=false,
    context~,
  )
  let result = group.spawn(no_wait?, () => {
    @event_loop.wait_pid(pid, context~) catch {
      _ if @coroutine.is_being_cancelled() =>
        @async.protect_from_cancel(() => {
          @async.with_task_group(group => {
            group.spawn_bg(no_wait=true, () => cancel_handler(pid))
            @event_loop.wait_pid(pid, context~)
          })
        })
      err => raise err
    }
  })
  { pid, result }
}

///|
/// Run a process and collect its standard output.
/// Return the exit code of the process and the content of its standard output.
///
/// The meaning of parameters is the same as `@process.run`
pub async fn collect_stdout(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@io.Data) {
  let (r, w) = read_from_process()
  @async.with_task_group(group => {
    defer r.close()
    let exit_code = group.spawn(() => {
      run(cmd, args, extra_env~, inherit_env~, stdin?, stdout=w, stderr?, cwd?)
    })
    let output = r.read_all()
    (exit_code.wait(), output)
  })
}

///|
/// Run a process and collect its standard error.
/// Return the exit code of the process and the content of its standard error.
///
/// The meaning of parameters is the same as `@process.run`
pub async fn collect_stderr(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@io.Data) {
  let (r, w) = read_from_process()
  @async.with_task_group(group => {
    defer r.close()
    let exit_code = group.spawn(() => {
      run(cmd, args, extra_env~, inherit_env~, stdin?, stdout?, stderr=w, cwd?)
    })
    let output = r.read_all()
    (exit_code.wait(), output)
  })
}

///|
/// Run a process and collect its standard output & standard error.
/// Return the exit code of the process, the content of its standard output,
/// and the content of its standard error.
///
/// The meaning of parameters is the same as `@process.run`
pub async fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@io.Data, &@io.Data) {
  let (r_out, w_out) = read_from_process()
  let (r_err, w_err) = read_from_process()
  @async.with_task_group(group => {
    let exit_code = group.spawn(() => {
      run(
        cmd,
        args,
        extra_env~,
        inherit_env~,
        stdin?,
        stdout=w_out,
        stderr=w_err,
        cwd?,
      )
    })
    let stdout = group.spawn(() => {
      defer r_out.close()
      r_out.read_all()
    })
    let stderr = group.spawn(() => {
      defer r_err.close()
      r_err.read_all()
    })
    (exit_code.wait(), stdout.wait(), stderr.wait())
  })
}

///|
/// Run a process, merge and collect its standard output & standard error.
/// Return the exit code of the process,
/// and the content of its standard output and standard error.
///
/// The meaning of parameters is the same as `@process.run`
pub async fn collect_output_merged(
  cmd : StringView,
  args : Array[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@io.Data) {
  let (r, w) = read_from_process()
  @async.with_task_group(group => {
    defer r.close()
    let exit_code = group.spawn(() => {
      run(cmd, args, extra_env~, inherit_env~, stdin?, stdout=w, stderr=w, cwd?)
    })
    let output = r.read_all()
    (exit_code.wait(), output)
  })
}
