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
async test "collect_stdout" {
  let (code, output) = @process.collect_stdout(shell, [
    "-c",
    "\{write_stdout} abcd",
  ])
  inspect(code, content="0")
  inspect(output.text(), content="abcd")
}

///|
async test "collect_error" {
  let (code, output) = @process.collect_stderr(shell, [
    "-c",
    "\{write_stderr} abcd",
  ])
  inspect(code, content="0")
  inspect(output.text(), content="abcd")
}

///|
async test "collect_output" {
  let (code, stdout, stderr) = @process.collect_output(shell, [
    "-c",
    "\{write_stdout} ab; \{write_stderr} ab; \{write_stdout} cd; \{write_stderr} cd",
  ])
  inspect(code, content="0")
  inspect(stdout.text(), content="abcd")
  inspect(stderr.text(), content="abcd")
}

///|
async test "collect_output_merged" {
  let (code, output) = @process.collect_output_merged(shell, [
    "-c",
    "\{write_stdout} ab; \{write_stderr} ab; \{write_stdout} cd; \{write_stderr} cd",
  ])
  inspect(code, content="0")
  inspect(output.text(), content="ababcdcd")
}

///|
async test "collect_output blocked" {
  let test_prog = cat.wait()
  @async.with_task_group(group => {
    let (cat_read, we_write) = @process.write_to_process()
    group.spawn_bg(() => {
      defer we_write.close()
      let chunk = Bytes::make(1024, 0)
      for _ in 0..<1024 {
        we_write.write(chunk)
      }
    })
    let (code, stdout, stderr) = @process.collect_output(
      test_prog,
      ["-stderr"],
      stdin=cat_read,
    )
    inspect(code, content="0")
    inspect(stdout.text(), content="")
    inspect(stderr.binary().length(), content="1048576")
  })
}
