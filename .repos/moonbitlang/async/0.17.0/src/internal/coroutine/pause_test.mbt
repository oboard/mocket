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
test "coroutine ping-pong" {
  let log = StringBuilder::new()
  let coro = @coroutine.spawn(() => {
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        log.write_string("ping\n")
        @async.pause()
        log.write_string("ping\n")
        @async.pause()
        log.write_string("ping\n")
      })
      group.spawn_bg(() => {
        log.write_string("pong\n")
        @async.pause()
        log.write_string("pong\n")
        @async.pause()
        log.write_string("pong\n")
      })
    })
  })
  while !@coroutine.no_more_work() {
    @coroutine.reschedule()
  }
  coro.unwrap()
  inspect(
    log.to_string(),
    content=(
      #|ping
      #|pong
      #|ping
      #|pong
      #|ping
      #|pong
      #|
    ),
  )
}
