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
async test "set cwd" {
  @async.with_task_group(root => {
    // FIXME(upstram): missing codelens here
    guard @env.current_dir() is Some(prev_cwd)
    let (r, w) = @process.read_from_process()
    defer r.close()
    root.spawn_bg(() => {
      let _ = @process.run(shell, ["-c", ls], stdout=w, cwd="src/process", extra_env={
        "LC_ALL": "C",
      })
      guard @env.current_dir() is Some(new_cwd)
      guard prev_cwd == new_cwd
    })
    let files = r
      .read_all()
      .text()
      .trim(char_set="\n\r ")
      .replace_all(old="\r\n", new="\n")
      .split("\n")
      .to_array()
    files.sort()
    json_inspect(files, content=[
      "stub.c", "moon.pkg", "unix.mbt", "README.md", "windows.c", "process.mbt",
      "windows.mbt", "cwd_test.mbt", "env_test.mbt", "redirect.mbt", "README.mbt.md",
      "test_programs", "wait_test.mbt", "basic_test.mbt", "cancel_test.mbt", "helper_test.mbt",
      "cancellation.mbt", "redirect_test.mbt", "unimplemented.mbt", "pkg.generated.mbti",
      "commands_for_test.mbt", "unimplemented_test.mbt", "spawn_in_group_test.mbt",
      "windows_escape_wbtest.mbt",
    ])
  })
}
