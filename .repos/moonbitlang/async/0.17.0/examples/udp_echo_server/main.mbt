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
async fn main {
  @async.with_task_group(root => {
    let server = @socket.UdpServer(@socket.Addr::parse("0.0.0.0:4200"))
    defer server.close()
    for ;; {
      let buf = FixedArray::make(1024, b'0')
      let (n, addr) = server.recvfrom(buf)
      root.spawn_bg(() => {
        let buf = buf.unsafe_reinterpret_as_bytes()
        server.sendto(buf[0:n].to_bytes(), addr)
      })
    }
  })
}
