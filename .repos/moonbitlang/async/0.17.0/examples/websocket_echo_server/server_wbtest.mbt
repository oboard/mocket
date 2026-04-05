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
async test "test server" {
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => start_echo_server())
    let client = @websocket.connect("ws://localhost:9001")
    defer client.close()
    client.send_binary("abcd")
    let msg = client.recv()
    inspect(msg.kind, content="Binary")
    inspect(msg.read_all().text(), content="abcd")
    client.send_text("abcd")
    let msg = client.recv()
    inspect(msg.kind, content="Text")
    inspect(msg.read_all().text(), content="abcd")
    client.send_close()
  })
}
