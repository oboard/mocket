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
#cfg(not(platform="windows"))
async fn test_server(r : &@io.Reader, w : &@io.Writer) -> @tls.Tls {
  @tls.Tls::server_from_pair(
    r,
    w,
    private_key_file="test_keys/key.pem",
    private_key_type=PEM,
    certificate_file="test_keys/cert.pem",
    certificate_type=PEM,
  )
}

///|
#cfg(platform="windows")
async fn test_server(r : &@io.Reader, w : &@io.Writer) -> @tls.Tls {
  @tls.Tls::server_from_pair(r, w)
}

///|
async test "one way" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (client_read_from_server, server_write_to_client) = @pipe.pipe()
    let (server_read_from_client, client_write_to_server) = @pipe.pipe()
    // server
    root.spawn_bg(() => {
      defer {
        server_read_from_client.close()
        server_write_to_client.close()
      }
      let server = test_server(server_read_from_client, server_write_to_client)
      defer server.close()
      while server.read_some() is Some(data) {
        let data = @utf8.decode(data)
        log.write_string("server received: \{data}\n")
      } nobreak {
        server.shutdown()
      }
    })
    // client
    root.spawn_bg(() => {
      defer {
        client_read_from_server.close()
        client_write_to_server.close()
      }
      let client = @tls.Tls::client_from_pair(
        client_read_from_server,
        client_write_to_server,
        verify=false,
      )
      defer client.close()
      client.write(b"abcd")
      @async.sleep(50)
      client.write(b"efgh")
      @async.sleep(50)
      client.write(b"ijkl")
      client.shutdown()
      inspect(client.read_all().text(), content="")
    })
  })
  inspect(
    log.to_string(),
    content=(
      #|server received: abcd
      #|server received: efgh
      #|server received: ijkl
      #|
    ),
  )
}

///|
async test "echo" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (client_read_from_server, server_write_to_client) = @pipe.pipe()
    let (server_read_from_client, client_write_to_server) = @pipe.pipe()
    // server
    root.spawn_bg(() => {
      defer {
        server_read_from_client.close()
        server_write_to_client.close()
      }
      let server = test_server(server_read_from_client, server_write_to_client)
      defer server.close()
      while server.read_some() is Some(data) {
        log.write_string("server received: \{@utf8.decode(data)}\n")
        server.write(data)
      } nobreak {
        server.shutdown()
      }
    })
    // client
    root.spawn_bg(() => {
      defer {
        client_read_from_server.close()
        client_write_to_server.close()
      }
      let client = @tls.Tls::client_from_pair(
        client_read_from_server,
        client_write_to_server,
        verify=false,
      )
      defer client.close()
      for data in [b"abcd", b"efgh", b"ijkl"] {
        client.write(data)
        assert_eq(client.read_exactly(4), data)
        @async.sleep(50)
      }
      client.shutdown()
      inspect(client.read_all().text(), content="")
    })
  })
  inspect(
    log.to_string(),
    content=(
      #|server received: abcd
      #|server received: efgh
      #|server received: ijkl
      #|
    ),
  )
}

///|
async test "`connect` accidental close" {
  @async.with_task_group(root => {
    let (client_read_from_server, server_write_to_client) = @pipe.pipe()
    let (server_read_from_client, client_write_to_server) = @pipe.pipe()
    // server
    root.spawn_bg(() => {
      defer {
        server_read_from_client.close()
        server_write_to_client.close()
      }
      let _ = server_read_from_client.read_some()
      @async.sleep(100)
    })
    // client
    root.spawn_bg(() => {
      defer {
        client_read_from_server.close()
        client_write_to_server.close()
      }
      let client = try? @tls.Tls::client_from_pair(
        client_read_from_server,
        client_write_to_server,
        verify=false,
      )
      match client {
        Ok(client) => {
          client.close()
          fail("expected `ConnectionClosed` error")
        }
        Err(err) => inspect(err, content="ConnectionClosed")
      }
    })
  })
}

///|
async test "`read` already closed" {
  @async.with_task_group(root => {
    let (client_read_from_server, server_write_to_client) = @pipe.pipe()
    let (server_read_from_client, client_write_to_server) = @pipe.pipe()
    // server
    root.spawn_bg(() => {
      defer {
        server_read_from_client.close()
        server_write_to_client.close()
      }
      let server = test_server(server_read_from_client, server_write_to_client)
      server.close()
    })
    // client
    root.spawn_bg(() => {
      defer {
        client_read_from_server.close()
        client_write_to_server.close()
      }
      let client = @tls.Tls::client_from_pair(
        client_read_from_server,
        client_write_to_server,
        verify=false,
      )
      defer client.close()
      inspect(try? client.read_some(), content="Ok(None)")
    })
  })
}
