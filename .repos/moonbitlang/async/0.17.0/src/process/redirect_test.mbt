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
async test "merge multiple" {
  @async.with_task_group(root => {
    let (r, w) = @pipe.pipe()
    root.spawn_bg(no_wait=true, () => {
      defer r.close()
      inspect(
        r.read_all().text(),
        content=(
          #|abcd
          #|efgh
          #|
        ),
      )
    })
    defer w.close()
    @async.with_task_group(group => {
      @process.spawn(group, shell, ["-c", "echo abcd"], stdout=w, extra_env={
        "LANG": "en_US.UTF-8",
      })
      |> ignore
      @process.spawn(group, shell, ["-c", "sleep 1; echo efgh"], stdout=w, extra_env={
        "LANG": "en_US.UTF-8",
      })
      |> ignore
    })
  })
}

///|
async test "redirect to file" {
  let cat = cat.wait()
  @async.with_task_group(root => {
    let input_file = "_build/process_redirect_test_in.txt"
    let output_file = "_build/process_redirect_test_out.txt"
    root.add_defer(() => @fs.remove(input_file))
    root.add_defer(() => @fs.remove(output_file))
    @fs.write_file(input_file, "abcd", create=0o644)
    let _ = @process.run(
      cat,
      [],
      stdin=@process.redirect_from_file(input_file),
      stdout=@process.redirect_to_file(output_file, create=0o644),
    )
    inspect(@fs.read_file(output_file).text(), content="abcd")
  })
}

///|
async test "merge stdout and stderr" {
  @async.with_task_group(group => {
    let (r, w) = @process.read_from_process()
    defer r.close()
    let _ = @process.spawn(
      group,
      shell,
      ["-c", "\{write_stdout} abcd; \{write_stderr} efgh"],
      stdout=w,
      stderr=w,
    )
    inspect(r.read_all().text(), content="abcdefgh")
  })
}
