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
extern "C" fn get_curr_env() -> FixedArray[@os_string.OsString?] = "moonbitlang_async_get_curr_env"

///|
#cfg(not(platform="windows"))
let curr_env : FixedArray[@os_string.OsString?] = get_curr_env()

///|
#cfg(not(platform="windows"))
async fn raw_spawn(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String],
  inherit_env~ : Bool,
  stdin~ : &ProcessInput?,
  stdout~ : &ProcessOutput?,
  stderr~ : &ProcessOutput?,
  cwd~ : StringView?,
  is_orphan~ : Bool,
  context~ : String,
) -> Int {
  let cmd = @os_string.encode(cmd)
  let argv = FixedArray::make(args.length() + 2, None)
  let cwd = match cwd {
    None => None
    Some(cwd) => Some(@os_string.encode(cwd))
  }
  argv[0] = Some(cmd)
  for i in 0..<args.length() {
    argv[i + 1] = Some(@os_string.encode(args[i]))
  }
  defer {
    if stdin is Some(p) {
      p.after_spawn()
    }
    if stdout is Some(p) {
      p.after_spawn()
    }
    if stderr is Some(p) {
      p.after_spawn()
    }
  }
  let stdin = match stdin {
    Some(pipe) => {
      @fd_util.set_blocking(pipe.fd(), context~)
      pipe.fd()
    }
    None => -1
  }
  let stdout = match stdout {
    Some(pipe) => {
      @fd_util.set_blocking(pipe.fd(), context~)
      pipe.fd()
    }
    None => -1
  }
  let stderr = match stderr {
    Some(pipe) => {
      @fd_util.set_blocking(pipe.fd(), context~)
      pipe.fd()
    }
    None => -1
  }
  let extra_count = extra_env.length()
  let env = match (inherit_env, extra_count) {
    (true, 0) => curr_env
    (false, 0) => [None]
    (_, n) => {
      let curr_env = if inherit_env { curr_env } else { [None] }
      let envp = FixedArray::make(n + curr_env.length(), None)
      let mut i = 0
      for k, v in extra_env {
        envp[i] = Some(@os_string.encode("\{k}=\{v}"))
        i = i + 1
      }
      curr_env.blit_to(envp, src_offset=0, dst_offset=i, len=curr_env.length())
      envp
    }
  }
  // currently auto kill child process on hard termination is not supported on Unix,
  // so `is_orphan` makes no difference on actual spawning
  ignore(is_orphan)
  @event_loop.spawn(cmd, argv, env~, stdin~, stdout~, stderr~, cwd~, context~)
}
