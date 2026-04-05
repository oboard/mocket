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
async test "basic sleep" {
  let buf = StringBuilder::new()
  let result = try? @async.with_task_group(root => {
    root.spawn_bg(() => {
      @async.sleep(100)
      buf.write_string("task 1, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 3\n")
    })
    root.spawn_bg(() => {
      @async.sleep(200)
      buf.write_string("task 2, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 3\n")
    })
  })
  inspect(result, content="Ok(())")
  inspect(
    buf.to_string(),
    content=(
      #|task 1, tick 1
      #|task 2, tick 1
      #|task 1, tick 2
      #|task 2, tick 2
      #|task 1, tick 3
      #|task 2, tick 3
      #|
    ),
  )
}

///|
async test "Timer basic" {
  let log = []
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(150)
      log.push("sleep: tick #1")
      @async.sleep(300)
      log.push("sleep: tick #2")
      @async.sleep(300)
      log.push("sleep: tick #3")
    })
    @async.sleep(300)
    log.push("creating timer")
    let timer = @async.Timer(300)
    @async.with_task_group(group => {
      for _ in 0..<3 {
        group.spawn_bg(() => {
          timer.wait()
          log.push("timer completed")
        })
      }
    })
    log.push("wait again: \{@async.with_timeout_opt(0, () => timer.wait())}")
  })
  json_inspect(log, content=[
    "sleep: tick #1", "creating timer", "sleep: tick #2", "timer completed", "timer completed",
    "timer completed", "wait again: Some(())", "sleep: tick #3",
  ])
}

///|
async test "Timer no waiter" {
  let timer = @async.Timer(200)
  @async.sleep(400)
  inspect(
    @async.with_timeout_opt(0, () => timer.wait()),
    content=(
      #|Some(())
    ),
  )
}

///|
async test "Timer no one waiting" {
  let _ = @async.Timer(1000000)
  @async.pause()
}

///|
async test "Timer waiter cancelled 1" {
  let timer = @async.Timer(600)
  assert_true(@async.with_timeout_opt(200, () => timer.wait()) is None)
  @async.sleep(200)
  assert_false(@async.with_timeout_opt(300, () => timer.wait()) is None)
}

///|
async test "Timer waiter cancelled 2" {
  let timer = @async.Timer(300)
  assert_true(@async.with_timeout_opt(200, () => timer.wait()) is None)
  @async.sleep(200)
  assert_false(@async.with_timeout_opt(0, () => timer.wait()) is None)
}

///|
async test "Timer::cancel" {
  let log = []
  let start = @async.now()
  let timer = @async.Timer(450)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(150)
      timer.cancel()
    })
    group.spawn_bg(() => {
      let result = try? timer.wait()
      let tick = (@async.now() - start + 50).to_int() / 150
      log.push("Timer::wait(): \{result} at tick #\{tick}")
    })
    @async.sleep(600)
    let tick = (@async.now() - start + 50).to_int() / 150
    log.push("at tick #\{tick}: Timer::wait(): \{try? timer.wait()}")
    timer.cancel()
    log.push("at tick #\{tick}: Timer::wait(): \{try? timer.wait()}")
  })
  json_inspect(log, content=[
    "Timer::wait(): Err(TimerCancelled) at tick #1", "at tick #4: Timer::wait(): Err(TimerCancelled)",
    "at tick #4: Timer::wait(): Err(TimerCancelled)",
  ])
}

///|
async test "Timer::refresh has waiter" {
  let log = []
  let start = @async.now()
  fn tick() -> Int {
    (@async.now() - start + 50).to_int() / 150
  }

  let timer = @async.Timer(300)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      timer.wait()
      log.push("Timer::wait() completed at tick #\{tick()}")
    })
    group.spawn_bg(() => {
      @async.sleep(150)
      log.push("refresh timer at #\{tick()}")
      timer.refresh()
    })
    group.spawn_bg(() => {
      @async.sleep(300)
      log.push("refresh timer at #\{tick()}")
      timer.refresh()
    })
  })
  json_inspect(log, content=[
    "refresh timer at #1", "refresh timer at #2", "Timer::wait() completed at tick #4",
  ])
}

///|
async test "Timer::refresh no waiter" {
  let log = []
  let start = @async.now()
  fn tick() -> Int {
    (@async.now() - start + 50).to_int() / 150
  }

  let timer = @async.Timer(300)
  @async.sleep(150)
  timer.refresh()
  log.push("refresh timer at tick #\{tick()}")
  timer.wait()
  log.push("Timer::wait() completed at tick #\{tick()}")
  json_inspect(log, content=[
    "refresh timer at tick #1", "Timer::wait() completed at tick #3",
  ])
}

///|
async test "Timer::refresh already terminated" {
  let log = []
  let start = @async.now()
  fn tick() -> Int {
    (@async.now() - start + 50).to_int() / 150
  }

  let timer = @async.Timer(300)
  @async.sleep(450)
  timer.refresh()
  log.push("refresh timer at tick #\{tick()}")
  timer.wait()
  log.push("Timer::wait() completed at tick #\{tick()}")
  json_inspect(log, content=[
    "refresh timer at tick #3", "Timer::wait() completed at tick #5",
  ])
}

///|
async test "Timer::refresh already cancelled" {
  let timer = @async.Timer(300)
  timer.cancel()
  timer.refresh()
  inspect(
    @async.with_timeout_opt(0, () => try? timer.wait()),
    content=(
      #|Some(Err(TimerCancelled))
    ),
  )
}
