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
async test "cancel process" {
  let test_prog = sleep_prog.wait()
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @process.read_from_process()
    let task = root.spawn(() => {
      defer log.write_string("process terminates\n")
      @process.run(test_prog, ["10000"], stdout=w)
    })
    root.spawn_bg(() => {
      defer r.close()
      while r.read_some() is Some(data) {
        let data = @utf8.decode(data).replace_all(old="\r\n", new="\n")
        log.write_string("from process: \{data}")
      }
    })
    @async.sleep(500)
    task.cancel()
    log.write_string("cancelling task running process\n")
  })
  inspect(
    log.to_string(),
    content=(
      #|cancelling task running process
      #|from process: received termination signal
      #|process terminates
      #|
    ),
  )
}

///|
async test "cancel process timeout" {
  let test_prog = sleep_prog.wait()
  @async.with_task_group(root => {
    let (r, w) = @process.read_from_process()
    let task = root.spawn(() => {
      @process.run(
        test_prog,
        ["-swallow-cancel-signal", "10000"],
        stdout=w,
        cancel_handler=@process.graceful_cancel(timeout=500),
      )
    })
    let t_receive_graceful_termination = root.spawn(() => {
      defer r.close()
      guard r.read_some() is Some(data)
      let data = @utf8.decode(data).trim_end(chars="\r\n")
      let t = @async.now()
      inspect(data, content="received termination signal")
      t
    })
    @async.sleep(500)
    let t_cancel = @async.now()
    task.cancel()
    inspect(try? task.wait(), content="Err(Cancelled)")
    let t_process_terminates = @async.now()
    let t1 = t_receive_graceful_termination.wait() - t_cancel
    let t2 = t_process_terminates - t_cancel
    inspect(t1 / 250, content="0")
    inspect(t2 / 250, content="2")
  })
}

///|
async test "cancel process hard" {
  let test_prog = sleep_prog.wait()
  @async.with_task_group(root => {
    let (r, w) = @process.read_from_process()
    let task = root.spawn(() => {
      @process.run(
        test_prog,
        ["10000"],
        stdout=w,
        cancel_handler=@process.hard_cancel(),
      )
    })
    root.spawn_bg(() => {
      defer r.close()
      inspect(r.read_all().text(), content="")
    })
    @async.sleep(500)
    let t0 = @async.now()
    task.cancel()
    inspect(try? task.wait(), content="Err(Cancelled)")
    let t1 = @async.now()
    inspect((t1 - t0) / 250, content="0")
  })
}

///|
async test "orphan process" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @process.read_from_process()
    let task = root.spawn(() => {
      defer log.write_string("process terminates\n")
      let pid = @process.spawn_orphan(
        shell,
        ["-c", "\{write_stdout} first; sleep 1; \{write_stdout} second"],
        stdout=w,
      )
      @process.wait_pid(pid)
    })
    defer r.close()
    inspect(@utf8.decode(r.read_exactly(5)), content="first")
    task.cancel()
    log.write_string("cancelling task running process\n")
    inspect(r.read_all().text(), content="second")
  })
  inspect(
    log.to_string(),
    content=(
      #|cancelling task running process
      #|process terminates
      #|
    ),
  )
}

///|
#cfg(platform="windows")
async test "kill children on hard cancel" {
  let spawn = spawn_prog.wait()
  let sleep = sleep_prog.wait()
  let (r, w) = @process.read_from_process()
  defer r.close()
  @async.with_timeout(300, () => {
    @process.run(
      spawn,
      [sleep, "450", "-print-after-sleep", "after sleep"],
      stdout=w,
      cancel_handler=@process.hard_cancel(),
    )
    |> ignore
  }) catch {
    @async.TimeoutError => ()
    err => raise err
  }
  inspect(r.read_all().text().trim(), content="")
}

///|
async test "do not kill orphan children on hard cancel" {
  let spawn = spawn_prog.wait()
  let sleep = sleep_prog.wait()
  let (r, w) = @process.read_from_process()
  defer r.close()
  @async.with_timeout(300, () => {
    @process.run(
      spawn,
      ["-orphan", sleep, "450", "-print-after-sleep", "after sleep"],
      stdout=w,
      cancel_handler=@process.hard_cancel(),
    )
    |> ignore
  }) catch {
    @async.TimeoutError => ()
    err => raise err
  }
  inspect(r.read_all().text().trim(), content="after sleep")
}
