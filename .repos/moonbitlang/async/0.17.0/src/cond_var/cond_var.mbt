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
priv struct Waiter {
  // In the rare case where:
  //
  // - `signal` wake up a waiter, the piece of resource is assigned to that waiter
  // - the waiter is immediately cancelled after woken up by `signal`,
  //   but before the waiter's coroutine actually resumes execution
  //
  // we must swallow the cancellation signal,
  // as otherwise the signal will be gone forever.
  // So we set `woken = true` after waking up a waiter,
  // and use this flag to protect against dangerous cancellation.
  mut woken : Bool
  mut coro : @coroutine.Coroutine?
}

///|
/// A condition variable that can be used for synchronization between tasks.
pub struct Cond {
  priv waiters : @deque.Deque[Waiter]

  fn new() -> Cond
}

///|
/// Create a new condition variable.
pub fn Cond::new() -> Cond {
  { waiters: @deque.new() }
}

///|
/// Wait for the condition to get signaled.
/// `wait` itself never fail, and will wait indefinitely.
/// However, since `wait` is a blocking point,
/// the task running `wait` may be cancelled,
/// in this case, an cancellation will be raised from `wait`.
pub async fn Cond::wait(cond : Cond) -> Unit {
  let coro = @coroutine.current_coroutine()
  let waiter = { woken: false, coro: Some(coro) }
  cond.waiters.push_back(waiter)
  @coroutine.suspend() catch {
    _ if waiter.woken => ()
    err => {
      waiter.coro = None
      raise err
    }
  }
}

///|
/// Issue a single signal through the condition variable,
/// waking up the first task waiting for the condition variable.
/// If no task is waiting for the condition variable, nothing will happen.
pub fn Cond::signal(cond : Cond) -> Unit {
  loop cond.waiters.pop_front() {
    None => ()
    Some({ coro: None, .. }) => continue cond.waiters.pop_front()
    Some({ coro: Some(coro), .. } as waiter) => {
      waiter.woken = true
      coro.wake()
    }
  }
}

///|
/// Send a broadcast signal to the condition variable,
/// waking up all tasks waiting for the condition variable.
/// If no task is waiting for the condition variable, nothing will happen.
pub fn Cond::broadcast(cond : Cond) -> Unit {
  for waiter in cond.waiters {
    if waiter.coro is Some(coro) {
      waiter.woken = true
      coro.wake()
    }
  }
  cond.waiters.clear()
}
