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
async test "allow_failure ignored" {
  let buf = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(allow_failure=true, () => raise Err)
    @async.sleep(100)
    buf.write_string("main task terminate\n")
  })
  inspect(
    buf.to_string(),
    content=(
      #|main task terminate
      #|
    ),
  )
}

///|
async test "allow_failure waited" {
  let buf = StringBuilder::new()
  buf.write_object(
    try? @async.with_task_group(root => {
      let task = root.spawn(allow_failure=true, () => raise Err)
      @async.sleep(100)
      task.wait()
      buf.write_string("main task terminate\n")
    }),
  )
  inspect(buf.to_string(), content="Err(Err)")
}

///|
async test "allow_failure no error" {
  let buf = StringBuilder::new()
  buf.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(allow_failure=true, () => {
        @async.sleep(1000)
        buf.write_string("`allow_failure` task terminate\n")
      })
      @async.sleep(100)
      buf.write_string("main task terminate\n")
    }),
  )
  inspect(
    buf.to_string(),
    content=(
      #|main task terminate
      #|`allow_failure` task terminate
      #|Ok(())
    ),
  )
}
