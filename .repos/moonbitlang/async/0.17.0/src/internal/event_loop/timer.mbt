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
struct Timer {
  timer_id : Int
  expire_time : Int64
  callback : () -> Unit
}

///|
let timer_id : Ref[Int] = { val: 0 }

///|
pub fn Timer::new(duration : Int, callback : () -> Unit) -> Timer {
  guard curr_loop.val is Some(evloop)
  let expire_time = @time.ms_since_epoch() + duration.to_int64()
  timer_id.val += 1
  let timer = { timer_id: timer_id.val, expire_time, callback }
  evloop.timers.add(timer)
  timer
}

///|
pub fn Timer::cancel(timer : Timer) -> Unit {
  guard curr_loop.val is Some(evloop)
  evloop.timers.remove(timer)
}

///|
impl Eq for Timer with equal(t1, t2) {
  t1.timer_id == t2.timer_id
}

///|
impl Compare for Timer with compare(t1, t2) {
  match t1.expire_time.compare(t2.expire_time) {
    0 => t1.timer_id.compare(t2.timer_id)
    o => o
  }
}
