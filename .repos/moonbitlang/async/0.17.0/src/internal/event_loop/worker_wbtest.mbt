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
#cfg(target="native")
extern "C" fn Job::sleep(time : Int) -> Job = "moonbitlang_async_make_sleep_job"

///|
#cfg(target="native")
async fn perform_sleep_job(t : Int) -> Unit {
  perform_job_in_worker(Job::sleep(t), context="") |> ignore
}

///|
#cfg(target="js")
async fn perform_sleep_job(t : Int) -> Unit {
  @async.protect_from_cancel(() => @async.sleep(t), resume_on_cancel=true)
}

///|
async test "worker basic" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      for _ in 0..<3 {
        @async.sleep(400)
        log.write_string("tick\n")
      }
    })
    perform_sleep_job(1000)
    log.write_string("done\n")
  })
  inspect(
    log.to_string(),
    content=(
      #|tick
      #|tick
      #|done
      #|tick
      #|
    ),
  )
}

///|
async test "worker multiple" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      for _ in 0..<3 {
        @async.sleep(200)
        log.write_string("tick\n")
      }
    })
    for i in 0..<3 {
      root.spawn_bg(() => {
        perform_sleep_job(100 + i * 200)
        log.write_string("#\{i} done\n")
      })
    }
  })
  inspect(
    log.to_string(),
    content=(
      #|#0 done
      #|tick
      #|#1 done
      #|tick
      #|#2 done
      #|tick
      #|
    ),
  )
}

///|
async test "worker cancel1" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      for _ in 0..<4 {
        @async.sleep(200)
        log.write_string("tick\n")
      }
    })
    let task = root.spawn(() => {
      try perform_sleep_job(1000) catch {
        err => {
          log.write_string("sleep cancelled with \{err}\n")
          raise err
        }
      } noraise {
        _ => log.write_string("done\n")
      }
    })
    @async.sleep(500)
    log.write_string("trying to cancel\n")
    task.cancel()
  })
  inspect(
    log.to_string(),
    content=(
      #|tick
      #|tick
      #|trying to cancel
      #|tick
      #|tick
      #|done
      #|
    ),
  )
}

///|
async test "worker cancel2" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      for _ in 0..<3 {
        @async.sleep(400)
        log.write_string("tick\n")
      }
    })
    root.spawn_bg(allow_failure=true, () => {
      try perform_sleep_job(1000) catch {
        err => {
          log.write_string("sleep cancelled with \{err}\n")
          raise err
        }
      } noraise {
        _ => log.write_string("done\n")
      }
    })
    @async.sleep(600)
    log.write_string("trying to terminate now\n")
    root.return_immediately(())
  })
  inspect(
    log.to_string(),
    content=(
      #|tick
      #|trying to terminate now
      #|done
      #|
    ),
  )
}
