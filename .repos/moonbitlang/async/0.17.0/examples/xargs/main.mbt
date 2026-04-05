///|
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
let help_message : String =
  #|Usage: xargs OPTIONS COMMAND ..ARGS
  #|Run COMMAND with initial arguments ARGS and more arguments read from stdin.
  #|  COMMAND will be run once for every line in the input.
  #|
  #|Options:
  #|   -j COUNT,
  #|   --jobs COUNT    limit the max number of parallel jobs to `COUNT`
  #|
  #|   -h, --help      show this help message
  #|   --              treat all remaining arguments as the command line to run

///|
async fn main {
  let mut max_jobs = None
  let command_and_args = loop @env.args()[1:] {
    ["-j" | "--jobs" as opt, .. rest] => {
      guard rest is [count, .. rest] else {
        fail("expected max job count after `\{opt}`")
      }
      let count = @string.parse_int(count)
      // Use a semaphore to limit the max number of parallel jobs
      max_jobs = Some(@async.Semaphore::new(count))
      continue rest
    }
    ["-h" | "--help", ..] => {
      println(help_message)
      return
    }
    ["--", .. command_and_args] => command_and_args
    [['-', ..] as opt, ..] => fail("unknown option: `\{opt}`")
    command_and_args => command_and_args
  }
  guard command_and_args is [cmd, .. args] else { fail("no command specified") }
  @async.with_task_group(group => {
    while @stdio.stdin.read_until("\n") is Some(line) {
      if max_jobs is Some(limit) {
        limit.acquire()
      }
      group.spawn_bg(() => {
        defer (if max_jobs is Some(limit) { limit.release() })
        ignore(@process.run(cmd, [..args, line]))
      })
    }
  })
}
