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
let is_windows : Bool = @event_loop.IS_WINDOWS

///|
let shell : String = if is_windows { "powershell" } else { "sh" }

///|
let write_stdout : String = if is_windows {
  "Write-Host -NoNewline"
} else {
  "printf"
}

///|
let write_stderr : String = if is_windows {
  "& { [Console]::Error.Write($args[0]) }"
} else {
  "printf >&2"
}

///|
let ls : String = if is_windows { "Get-ChildItem -Name" } else { "ls" }

///|
fn make_test_prog(name : String) -> @async.Lazy[String] {
  @async.Lazy(() => {
    let code = @process.run("moon", [
      "build",
      "--manifest-path",
      "src/process/test_programs/moon.mod.json",
      "src/process/test_programs/\{name}",
      "--debug",
    ])
    if code != 0 {
      fail("failed to build test program `\{name}`: \{code}")
    }
    "src/process/test_programs/_build/native/debug/build/\{name}/\{name}.exe"
  })
}

///|
let sleep_prog : @async.Lazy[String] = make_test_prog("sleep")

///|
let dump_env_prog : @async.Lazy[String] = make_test_prog("dump_env")

///|
let cat : @async.Lazy[String] = make_test_prog("cat")

///|
let spawn_prog : @async.Lazy[String] = make_test_prog("spawn")
