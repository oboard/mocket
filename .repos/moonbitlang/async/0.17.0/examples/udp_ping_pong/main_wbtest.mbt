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
async test "main" {
  let log = StringBuilder::new()
  fn println(msg) -> Unit {
    log..write_string(msg).write_string("\n")
  }

  let result = try? main_prog(println)
  log.write_string(result.to_string())
  inspect(
    log.to_string(),
    content=(
      #|client 0 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 0 received: pong
      #|client 1 sent: pong
      #|server received: pong
      #|server sent: pong
      #|client 1 received: pong
      #|client 2 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 2 received: pong
      #|client 3 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 3 received: pong
      #|client 4 sent: pong
      #|server received: pong
      #|server sent: pong
      #|client 4 received: pong
      #|client 5 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 5 received: pong
      #|client 6 sent: exit
      #|server received: exit
      #|server sent: pong
      #|server initiate terminate
      #|server terminate: ServerTerminate
      #|Ok(())
    ),
  )
}
