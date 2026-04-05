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
      #|received new connection
      #|client 0: connection established
      #|client 0 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 0 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 1: connection established
      #|client 1 sent: pong
      #|server received: pong
      #|server sent: pong
      #|client 1 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 2: connection established
      #|client 2 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 2 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 3: connection established
      #|client 3 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 3 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 4: connection established
      #|client 4 sent: pong
      #|server received: pong
      #|server sent: pong
      #|client 4 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 5: connection established
      #|client 5 sent: ping
      #|server received: ping
      #|server sent: pong
      #|client 5 received: pong
      #|server: connection closed by peer
      #|received new connection
      #|client 6: connection established
      #|client 6 sent: exit
      #|server received: exit
      #|server sent: pong
      #|server initiate terminate
      #|client 6 received: pong
      #|server terminate: ServerTerminate
      #|Ok(())
    ),
  )
}
