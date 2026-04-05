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
let lock_file_prog : @async.Lazy[String] = @async.Lazy(() => {
  let code = @process.run("moon", [
    "build", "--manifest-path", "src/process/test_programs/moon.mod.json", "src/process/test_programs/lock_file",
    "--debug",
  ])
  if code != 0 {
    fail("failed to build test program `lock_file`: \{code}")
  }
  "src/process/test_programs/_build/native/debug/build/lock_file/lock_file.exe"
})

///|
async fn run_lock_file_prog(
  group : @async.TaskGroup[Unit],
  file : String,
  lock : @fs.Lock,
  log : Array[String],
  duration? : Int = 500,
  prefix? : String = "",
) -> Unit {
  let prog = lock_file_prog.wait()
  let (r, w) = @process.read_from_process()
  let lock_kind = if lock is Exclusive { "-exclusive" } else { "-shared" }
  let _ = @process.spawn(group, prog, stdout=w, [
    file,
    "-duration",
    duration.to_string(),
    lock_kind,
  ])
  group.spawn_bg(() => {
    defer r.close()
    while r.read_until("\n") is Some(line) {
      log.push(prefix + line)
    }
  })
}

///|
async test "flock exclusive vs exclusive" {
  let log = []
  let file_name = "_build/flock_ex_ex"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log)
    @async.sleep(250)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
    @async.sleep(500)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
  })
  json_inspect(log, content=[
    "acquired lock", "try_lock() => false", "releasing lock", "try_lock() => true",
  ])
}

///|
async test "flock exclusive vs exclusive blocking" {
  let log = []
  let file_name = "_build/flock_ex_ex_blocking"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to acquire lock")
    file.lock(Exclusive)
    defer file.unlock()
    @async.sleep(10)
    log.push("acquired lock")
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to acquire lock", "child: releasing lock",
    "acquired lock",
  ])
}

///|
async test "flock shared vs exclusive" {
  let log = []
  let file_name = "_build/flock_sh_ex"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log)
    @async.sleep(250)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
    @async.sleep(500)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
  })
  json_inspect(log, content=[
    "acquired lock", "try_lock() => false", "releasing lock", "try_lock() => true",
  ])
}

///|
async test "flock shared vs exclusive blocking" {
  let log = []
  let file_name = "_build/flock_sh_ex_blocking"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to acquire lock")
    file.lock(Exclusive)
    defer file.unlock()
    @async.sleep(10)
    log.push("acquired lock")
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to acquire lock", "child: releasing lock",
    "acquired lock",
  ])
}

///|
async test "flock exclusive vs shared" {
  let log = []
  let file_name = "_build/flock_ex_sh"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log)
    @async.sleep(250)
    log.push("try_lock() => \{file.try_lock(Shared)}")
    @async.sleep(500)
    log.push("try_lock() => \{file.try_lock(Shared)}")
  })
  json_inspect(log, content=[
    "acquired lock", "try_lock() => false", "releasing lock", "try_lock() => true",
  ])
}

///|
async test "flock exclusive vs shared blocking" {
  let log = []
  let file_name = "_build/flock_ex_sh_blocking"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to acquire lock")
    file.lock(Shared)
    defer file.unlock()
    @async.sleep(10)
    log.push("acquired lock")
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to acquire lock", "child: releasing lock",
    "acquired lock",
  ])
}

///|
async test "flock shared vs shared" {
  let log = []
  let file_name = "_build/flock_sh_sh"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log)
    @async.sleep(250)
    log.push("try_lock() => \{file.try_lock(Shared)}")
  })
  json_inspect(log, content=[
    "acquired lock", "try_lock() => true", "releasing lock",
  ])
}

///|
async test "flock shared vs shared blocking" {
  let log = []
  let file_name = "_build/flock_sh_sh_blocking"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to acquire lock")
    file.lock(Shared)
    defer file.unlock()
    @async.sleep(10)
    log.push("acquired lock")
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to acquire lock", "acquired lock", "child: releasing lock",
  ])
}

///|
async test "flock shared vs shared vs exclusive" {
  let log = []
  let file_name = "_build/flock_sh_sh_ex"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log, prefix="child #1: ")
    @async.sleep(250)
    run_lock_file_prog(group, file_name, Shared, log, prefix="child #2: ")
    @async.sleep(100)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
    @async.sleep(200)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
    @async.sleep(450)
    log.push("try_lock() => \{file.try_lock(Exclusive)}")
  })
  json_inspect(log, content=[
    "child #1: acquired lock", "child #2: acquired lock", "try_lock() => false",
    "child #1: releasing lock", "try_lock() => false", "child #2: releasing lock",
    "try_lock() => true",
  ])
}

///|
async test "flock shared vs shared vs exclusive blocking" {
  let log = []
  let file_name = "_build/flock_sh_sh_ex_blocking"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Shared, log, prefix="child #1: ")
    @async.sleep(250)
    run_lock_file_prog(group, file_name, Shared, log, prefix="child #2: ")
    @async.sleep(100)
    log.push("attempting to acquire lock")
    file.lock(Exclusive)
    defer file.unlock()
    @async.sleep(10)
    log.push("acquired lock")
  })
  json_inspect(log, content=[
    "child #1: acquired lock", "child #2: acquired lock", "attempting to acquire lock",
    "child #1: releasing lock", "child #2: releasing lock", "acquired lock",
  ])
}

///|
async test "flock cancelled" {
  let log = []
  let file_name = "_build/flock_cancel"
  @async.with_task_group(group => {
    let file = @fs.open(file_name, create=0o644, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to acquire lock")
    let result = @async.with_timeout_opt(100, () => file.lock(Exclusive))
    log.push("lock() with timeout: \{result}")
    if result is Some(_) {
      file.unlock()
    }
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to acquire lock", "lock() with timeout: None",
    "child: releasing lock",
  ])
}

///|
async test "flock advisory" {
  let log = []
  let file_name = "_build/flock_advisory"
  @async.with_task_group(group => {
    @fs.write_file(file_name, create=0o644, "abcd")
    let file = @fs.open(file_name, mode=ReadWrite)
    defer file.close()
    group.add_defer(() => @fs.remove(file_name))
    run_lock_file_prog(group, file_name, Exclusive, log, prefix="child: ")
    @async.sleep(250)
    log.push("attempting to read")
    log.push("read from file: \{file.read_all().text()}")
  })
  json_inspect(log, content=[
    "child: acquired lock", "attempting to read", "read from file: abcd", "child: releasing lock",
  ])
}
