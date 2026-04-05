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
suberror ServerTerminate derive(Show)

///|
pub(all) struct Printer((String) -> Unit)

///|
async fn server_main(server : @socket.UdpServer, println : Printer) -> Unit {
  @async.with_task_group(group => {
    defer server.close()
    let buf = FixedArray::make(1024, b'0')
    while server.recvfrom(buf) is (n, addr) && n > 0 {
      group.spawn_bg(() => {
        @async.sleep(10)
        let msg = buf.unsafe_reinterpret_as_bytes()[0:n]
        println("server received: \{@utf8.decode(msg)}")
        let reply = "pong"
        server.sendto(@utf8.encode(reply), addr)
        println("server sent: \{reply}")
        if msg == b"exit" {
          println("server initiate terminate")
          raise ServerTerminate
        }
      })
    } nobreak {
      println("server: connection closed by peer")
    }
  }) catch {
    err => {
      println("server terminate: \{err}")
      raise err
    }
  }
}

///|
async fn client(
  addr : @socket.Addr,
  println : Printer,
  id : Int,
  msg : String,
) -> Unit {
  let conn = @socket.UdpClient(addr)
  defer conn.close()
  conn.send(@utf8.encode(msg))
  println("client \{id} sent: \{msg}")
  let buf = FixedArray::make(1024, b'0')
  if conn.recv(buf) is n && n > 0 {
    @async.sleep(10)
    let msg = buf.unsafe_reinterpret_as_bytes()[0:n]
    println("client \{id} received: \{@utf8.decode(msg)}")
  } else {
    println("client \{id}: connection closed by peer")
  }
}

///|
pub async fn main_prog(println : Printer) -> Unit {
  @async.with_task_group(root => {
    let server = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    root.spawn_bg(() => server_main(server, println))
    root.spawn_bg(() => {
      @async.with_task_group(ctx => {
        for i in 0..<6 {
          let msg = if i % 3 == 1 { "pong" } else { "ping" }
          ctx.spawn_bg(() => client(addr, println, i, msg))
          @async.sleep(100)
        }
      })
      root.spawn_bg(() => client(addr, println, 6, "exit"))
    })
  }) catch {
    ServerTerminate => ()
    err => raise err
  }
}

///|
async fn main {
  main_prog(println)
}
