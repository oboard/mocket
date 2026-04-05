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
async test "put after closed" {
  let q = @aqueue.new(kind=Unbounded)
  q.close()
  inspect(try? q.put(42), content="Err(QueueAlreadyClosed)")
  inspect(try? q.try_put(42), content="Err(QueueAlreadyClosed)")
}

///|
async test "get after closed" {
  let q = @aqueue.new(kind=Unbounded)
  q.put(42)
  q.close()
  inspect(try? q.get(), content="Ok(42)")
  inspect(try? q.get(), content="Err(QueueAlreadyClosed)")
}

///|
async test "try_get after closed" {
  let q = @aqueue.new(kind=Unbounded)
  q.put(42)
  q.close()
  inspect(try? q.try_get(), content="Ok(Some(42))")
  inspect(try? q.try_get(), content="Err(QueueAlreadyClosed)")
}

///|
async test "get after hard close" {
  let q = @aqueue.new(kind=Unbounded)
  q.put(42)
  q.close(clear=true)
  inspect(try? q.get(), content="Err(QueueAlreadyClosed)")
}

///|
async test "try_get after hard close" {
  let q = @aqueue.new(kind=Unbounded)
  q.put(42)
  q.close(clear=true)
  inspect(try? q.try_get(), content="Err(QueueAlreadyClosed)")
}

///|
async test "close with blocking put" {
  let q = @aqueue.new(kind=Blocking(1))
  q.put(1)
  @async.with_task_group(group => {
    let start = @async.now()
    group.spawn_bg(() => {
      @async.sleep(300)
      q.close()
    })
    inspect(try? q.put(2), content="Err(QueueAlreadyClosed)")
    let now = @async.now()
    let duration = (now + 50 - start) / 300
    inspect(duration, content="1")
  })
}

///|
async test "close zero buffered with blocking put" {
  let q = @aqueue.new(kind=Blocking(0))
  @async.with_task_group(group => {
    let start = @async.now()
    group.spawn_bg(() => {
      @async.sleep(300)
      q.close()
    })
    inspect(try? q.put(2), content="Err(QueueAlreadyClosed)")
    let now = @async.now()
    let duration = (now + 50 - start) / 300
    inspect(duration, content="1")
  })
}

///|
async test "close with blocking get" {
  let q : @aqueue.Queue[Int] = @aqueue.new(kind=Unbounded)
  @async.with_task_group(group => {
    let start = @async.now()
    group.spawn_bg(() => {
      @async.sleep(300)
      q.close()
    })
    inspect(try? q.get(), content="Err(QueueAlreadyClosed)")
    let now = @async.now()
    let duration = (now + 50 - start) / 300
    inspect(duration, content="1")
  })
}
