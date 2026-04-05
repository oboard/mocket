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
async test "bad client" {
  @async.with_task_group(group => {
    let server = @http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let server_result_queue = @async.Queue::new(kind=Unbounded)
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((req, _, conn) => {
        let ws = @websocket.from_http_server(req, conn)
        defer ws.close()
        let result = try? ({
          let result = ws.recv().read_all().text()
          ws.send_text(result)
          result
        })
        server_result_queue.put(result)
        // delay closing of the TCP connection,
        // so that the client has enough time to react to the CLOSE frame
        @async.sleep(50)
      })
    })
    async fn test_bad_frames(frames : Array[Bytes]) {
      let http_client = @http.Client::new("http://localhost:\{port}")
      defer http_client.close()
      let ws_client = @websocket.from_http_client(http_client, "/")
      defer ws_client.close()
      @async.with_task_group(group => {
        group.spawn_bg(() => {
          for frame in frames {
            http_client.write(frame)
          }
        })
        try? ws_client.recv().read_all().text()
      })
    }

    async fn test_bad_frame(frame) {
      test_bad_frames([frame])
    }

    // non-zero reserved bits
    inspect(
      test_bad_frame([0xc1, 0x00]),
      content=(
        #|Err(ConnectionClosed(MissingExtension, Some("Reserved bits are not zero")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Reserved bits are not zero"))
      ),
    )
    inspect(
      test_bad_frame([0xa1, 0x00]),
      content=(
        #|Err(ConnectionClosed(MissingExtension, Some("Reserved bits are not zero")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Reserved bits are not zero"))
      ),
    )
    inspect(
      test_bad_frame([0x91, 0x00]),
      content=(
        #|Err(ConnectionClosed(MissingExtension, Some("Reserved bits are not zero")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Reserved bits are not zero"))
      ),
    )

    // invalid OP code
    inspect(
      test_bad_frame([0x8b, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Invalid OP code 11")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Invalid OP code 11"))
      ),
    )
    inspect(
      test_bad_frame([0x8f, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Invalid OP code 15")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Invalid OP code 15"))
      ),
    )

    // invalid fragmentation

    // CONTINUATION frame outside a message
    inspect(
      test_bad_frame([0x80, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Unexpected continuation frame")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Unexpected continuation frame"))
      ),
    )

    // new message inside a fragmented one
    inspect(
      test_bad_frames([[0x01, 0x00], [0x81, 0x00]]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("New message within a fragmented message")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("New message within a fragmented message"))
      ),
    )

    // new fragmented message inside another fragmented one
    inspect(
      test_bad_frames([[0x01, 0x00], [0x01, 0x00]]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("New message within a fragmented message")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("New message within a fragmented message"))
      ),
    )

    // non-FIN control packets
    inspect(
      test_bad_frame([0x08, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Control frames must not be fragmented")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frames must not be fragmented"))
      ),
    )
    inspect(
      test_bad_frame([0x09, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Control frames must not be fragmented")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frames must not be fragmented"))
      ),
    )
    inspect(
      test_bad_frame([0x0a, 0x00]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Control frames must not be fragmented")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frames must not be fragmented"))
      ),
    )
    fn u16_to_bytes(len : UInt16) -> Bytes {
      let result = FixedArray::make(2, b'\x00')
      result.unsafe_write_uint16_be(0, len)
      result.unsafe_reinterpret_as_bytes()
    }

    // too-long control packets
    inspect(
      test_bad_frame([0x88, 126, ..u16_to_bytes(128)]),
      content=(
        #|Err(ConnectionClosed(MessageTooBig, Some("Control frame too long")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frame too long"))
      ),
    )
    inspect(
      test_bad_frame([0x89, 126, ..u16_to_bytes(128)]),
      content=(
        #|Err(ConnectionClosed(MessageTooBig, Some("Control frame too long")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frame too long"))
      ),
    )
    inspect(
      test_bad_frame([0x8a, 126, ..u16_to_bytes(128)]),
      content=(
        #|Err(ConnectionClosed(MessageTooBig, Some("Control frame too long")))
      ),
    )
    inspect(
      server_result_queue.get(),
      content=(
        #|Err(ProtocolError("Control frame too long"))
      ),
    )

    // invalid frame length
    inspect(
      test_bad_frame([0x81, 126, ..u16_to_bytes(125)]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Invalid payload length format")))
      ),
    )
    inspect(
      test_bad_frame([0x81, 127, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
      content=(
        #|Err(ConnectionClosed(ProtocolError, Some("Invalid payload length format")))
      ),
    )
  })
}
