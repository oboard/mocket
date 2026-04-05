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
async test "spawn error1" {
  let buf = StringBuilder::new()
  let result = try? @async.with_task_group(root => {
    root.spawn_bg(() => {
      @async.sleep(1000)
      buf.write_string("task 1 finished\n")
    })
    root.spawn_bg(() => {
      @async.sleep(200)
      raise Err
    })
  })
  buf.write_string(result.to_string())
  inspect(buf.to_string(), content="Err(Err)")
}

///|
async test "spawn error2" {
  let buf = StringBuilder::new()
  let result = try? @async.with_task_group(root => {
    root.spawn_bg(() => {
      @async.sleep(200)
      raise Err
    })
    root.spawn_bg(() => {
      @async.sleep(1000)
      buf.write_string("task 1 finished\n")
    })
  })
  buf.write_string(result.to_string())
  inspect(buf.to_string(), content="Err(Err)")
}

///|
async test "spawn after cancelled" {
  let log = []
  let _ : Result[Unit, _] = try? @async.with_task_group(group => {
    group.spawn_bg(() => {
      // emulate a non-cancellable job,
      // or a job that happens to be completed on cancellation,
      // such that discarding the result may lead to data loss
      @async.protect_from_cancel(() => @async.sleep(300), resume_on_cancel=true)
      // even if control flow enters here normally,
      // current task and the whole group may be in a cancelled state
      group.spawn_bg(allow_failure=true, () => {
        log.push("enter child task after cancelled")
        @async.sleep(100)
        log.push("child task completed")
      })
    })
    @async.sleep(150)
    raise Failure::Failure("failure")
  })
  json_inspect(log, content=["enter child task after cancelled"])
}
