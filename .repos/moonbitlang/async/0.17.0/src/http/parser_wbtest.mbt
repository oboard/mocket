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
fn log_headers(headers : Map[String, String], logger : &Logger) -> Unit {
  for k, v in headers {
    logger.write_string("\{k}: \{v}\n")
  }
}

///|
fn log_request(req : Request, logger : &Logger) -> Unit {
  logger.write_string("\{req.meth} \{req.path}\n")
  log_headers(req.headers, logger)
}

///|
fn log_response(req : Response, logger : &Logger) -> Unit {
  logger.write_string("\{req.code} \{req.reason}\n")
  log_headers(req.headers, logger)
}

///|
async test "read_request basic" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: x.y.org\r\n")
      .write("User-Agent: MoonBit\r\n\r\n")
    })
    defer r.close()
    let input = Reader::new(r)
    let request = input.read_request()
    log_request(request, log)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|Get /
      #|host: x.y.org
      #|user-agent: MoonBit
      #|
    ),
  )
}

///|
async test "read_request fixed body" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: x.y.org\r\n")
      ..write("User-Agent: MoonBit\r\n")
      ..write("Content-Length: 7\r\n\r\n")
      .write("message")
    })
    defer r.close()
    let input = Reader::new(r)
    let request = input.read_request()
    log_request(request, log)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|Get /
      #|host: x.y.org
      #|user-agent: MoonBit
      #|content-length: 7
      #|message
    ),
  )
}

///|
async test "read_request chunked" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: x.y.org\r\n")
      ..write("User-Agent: MoonBit\r\n")
      ..write("Transfer-Encoding: chunked\r\n\r\n")
      ..write("4\r\n")
      ..write("abcd\r\n")
      ..write("10\r\n")
      ..write("abcdefghijklmnop\r\n")
      .write("0\r\n\r\n")
    })
    defer r.close()
    let input = Reader::new(r)
    let request = input.read_request()
    log_request(request, log)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|Get /
      #|host: x.y.org
      #|user-agent: MoonBit
      #|transfer-encoding: chunked
      #|abcdabcdefghijklmnop
    ),
  )
}

///|
async test "read_request stream" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: x.y.org\r\n")
      ..write("User-Agent: MoonBit\r\n")
      .write("Transfer-Encoding: chunked\r\n\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nabcd\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nefgh\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nijkl\r\n")
      w.write("0\r\n\r\n")
    })
    defer r.close()
    let input = Reader::new(r)
    let request = input.read_request()
    log_request(request, log)
    while input.read_some() is Some(data) {
      let data = @utf8.decode(data)
      log.write_string("received \{data} from body\n")
    }
  })
  inspect(
    log.to_string(),
    content=(
      #|Get /
      #|host: x.y.org
      #|user-agent: MoonBit
      #|transfer-encoding: chunked
      #|writing data...
      #|received abcd from body
      #|writing data...
      #|received efgh from body
      #|writing data...
      #|received ijkl from body
      #|
    ),
  )
}

///|
async test "multiple request" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: x.y.org\r\n")
      ..write("User-Agent: MoonBit\r\n")
      .write("Transfer-Encoding: chunked\r\n\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nabcd\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nefgh\r\n")
      @async.sleep(50)
      log.write_string("writing data...\n")
      w.write("4\r\nijkl\r\n")
      w.write("0\r\n\r\n")
      @async.sleep(50)
      w
      ..write("GET / HTTP/1.1\r\n")
      ..write("Host: z.w.org\r\n")
      ..write("User-Agent: MoonBit\r\n")
      ..write("Content-Length: 8\r\n\r\n")
      .write("message2")
    })
    defer r.close()
    let input = Reader::new(r)
    let request = input.read_request()
    log_request(request, log)
    log..write_string(input.read_all().text()).write_string("\n\n=========\n\n")
    let request = input.read_request()
    log_request(request, log)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|Get /
      #|host: x.y.org
      #|user-agent: MoonBit
      #|transfer-encoding: chunked
      #|writing data...
      #|writing data...
      #|writing data...
      #|abcdefghijkl
      #|
      #|=========
      #|
      #|Get /
      #|host: z.w.org
      #|user-agent: MoonBit
      #|content-length: 8
      #|message2
    ),
  )
}

///|
async test "read_response basic" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 200 OK\r\n")
      ..write("Content-Length: 7\r\n\r\n")
      .write("message")
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|200 OK
      #|content-length: 7
      #|message
    ),
  )
}

///|
async test "read_response passthrough fallback (no length headers)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 200 OK\r\n")
      ..write("Connection: close\r\n")
      ..write("Content-Type: text/plain\r\n\r\n")
      // No Content-Length or Transfer-Encoding
      // Body ends when connection closes
      .write("Hello, World!")
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)

    // Read body via PassThrough fallback (reads until EOF/connection close)
    log.write_string(input.read_all().text())
  })
  inspect(
    log.to_string(),
    content=(
      #|200 OK
      #|connection: close
      #|content-type: text/plain
      #|Hello, World!
    ),
  )
}

///|
async test "read_response 204 No Content (no body)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 204 No Content\r\n")
      ..write("Connection: keep-alive\r\n")
      .write("Date: Mon, 15 Feb 2026 00:00:00 GMT\r\n\r\n")
      // 204 responses MUST NOT contain a message body
      // Connection remains open for next request
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)
    // Body should be Empty, not PassThrough
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|204 No Content
      #|connection: keep-alive
      #|date: Mon, 15 Feb 2026 00:00:00 GMT
      #|body: 
    ),
  )
}

///|
async test "read_response 205 Reset Content (no body)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 205 Reset Content\r\n")
      ..write("Connection: keep-alive\r\n")
      .write("Date: Mon, 15 Feb 2026 00:00:00 GMT\r\n\r\n")
      // 205 responses MUST NOT contain a message body
      // Connection remains open for next request
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)
    // Body should be Empty, not WaitConnectionClose
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|205 Reset Content
      #|connection: keep-alive
      #|date: Mon, 15 Feb 2026 00:00:00 GMT
      #|body: 
    ),
  )
}

///|
async test "read_response 304 Not Modified (no body)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 304 Not Modified\r\n")
      ..write("Connection: keep-alive\r\n")
      ..write("ETag: \"abc123\"\r\n")
      .write("Cache-Control: max-age=3600\r\n\r\n")
      // 304 responses MUST NOT contain a message body
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|304 Not Modified
      #|connection: keep-alive
      #|etag: "abc123"
      #|cache-control: max-age=3600
      #|body: 
    ),
  )
}

///|
async test "read_response 100 Continue (no body)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 100 Continue\r\n")
      .write("\r\n")
      // 1xx responses MUST NOT contain a message body
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=None)
    log_response(response, log)
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|100 Continue
      #|body: 
    ),
  )
}

///|
async test "read_response CONNECT 200 (no body, tunnel mode)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 200 Connection Established\r\n")
      .write("\r\n")
      // Successful CONNECT responses switch to tunnel mode
      // Connection remains open for tunneled traffic
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=Some(Connect))
    log_response(response, log)
    // Body should be Empty, not WaitConnectionClose
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|200 Connection Established
      #|body: 
    ),
  )
}

///|
async test "read_response HEAD 200 (no body)" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    let (r, w) = @io.pipe()
    root.spawn_bg(() => {
      defer w.close()
      w
      ..write("HTTP/1.1 200 OK\r\n")
      ..write("Content-Length: 1234\r\n")
      ..write("Content-Type: text/html\r\n")
      .write("\r\n")
      // HEAD responses never have a body, even with Content-Length
      // Connection remains open for next request
    })
    defer r.close()
    let input = Reader::new(r)
    let response = input.read_response(request_method=Some(Head))
    log_response(response, log)
    // Body should be Empty, not Fixed(1234)
    let body_text = input.read_all().text()
    log.write_string("body: ")
    log.write_string(body_text)
  })
  inspect(
    log.to_string(),
    content=(
      #|200 OK
      #|content-length: 1234
      #|content-type: text/html
      #|body: 
    ),
  )
}

///|
test "should_read_body_until_close - true cases" {
  let headers_no_length : Map[String, String] = {}

  // 200 OK with no length headers
  inspect(
    should_read_body_until_close(200, headers_no_length, Empty, None),
    content="true",
  )

  // 201 Created with no length headers
  inspect(
    should_read_body_until_close(201, headers_no_length, Empty, None),
    content="true",
  )

  // 202 Accepted with no length headers
  inspect(
    should_read_body_until_close(202, headers_no_length, Empty, None),
    content="true",
  )

  // 203 with no length headers
  inspect(
    should_read_body_until_close(203, headers_no_length, Empty, None),
    content="true",
  )

  // 3xx (except 304) with no length headers
  inspect(
    should_read_body_until_close(301, headers_no_length, Empty, None),
    content="true",
  )

  inspect(
    should_read_body_until_close(302, headers_no_length, Empty, None),
    content="true",
  )

  // 4xx with no length headers
  inspect(
    should_read_body_until_close(404, headers_no_length, Empty, None),
    content="true",
  )

  // 5xx with no length headers
  inspect(
    should_read_body_until_close(500, headers_no_length, Empty, None),
    content="true",
  )
}

///|
test "should_read_body_until_close - false cases (bodyless status codes)" {
  let headers_no_length : Map[String, String] = {}

  // 1xx informational responses
  inspect(
    should_read_body_until_close(100, headers_no_length, Empty, None),
    content="false",
  )

  inspect(
    should_read_body_until_close(101, headers_no_length, Empty, None),
    content="false",
  )

  inspect(
    should_read_body_until_close(199, headers_no_length, Empty, None),
    content="false",
  )

  // 204 No Content
  inspect(
    should_read_body_until_close(204, headers_no_length, Empty, None),
    content="false",
  )

  // 205 Reset Content
  inspect(
    should_read_body_until_close(205, headers_no_length, Empty, None),
    content="false",
  )

  // 304 Not Modified
  inspect(
    should_read_body_until_close(304, headers_no_length, Empty, None),
    content="false",
  )
}

///|
test "should_read_body_until_close - false cases (headers present)" {
  // Content-Length present
  let headers_with_length : Map[String, String] = { "content-length": "42" }
  inspect(
    should_read_body_until_close(200, headers_with_length, Empty, None),
    content="false",
  )

  // Transfer-Encoding present
  let headers_with_transfer : Map[String, String] = {
    "transfer-encoding": "chunked",
  }
  inspect(
    should_read_body_until_close(200, headers_with_transfer, Empty, None),
    content="false",
  )

  // Both present
  let headers_with_both : Map[String, String] = {
    "content-length": "42",
    "transfer-encoding": "chunked",
  }
  inspect(
    should_read_body_until_close(200, headers_with_both, Empty, None),
    content="false",
  )
}

///|
test "should_read_body_until_close - false cases (body already determined)" {
  let headers_no_length : Map[String, String] = {}

  // Body is Fixed (already determined by Content-Length)
  inspect(
    should_read_body_until_close(200, headers_no_length, Fixed(42), None),
    content="false",
  )

  // Body is Chunked (already determined by Transfer-Encoding)
  inspect(
    should_read_body_until_close(200, headers_no_length, Chunked(0), None),
    content="false",
  )

  // Body is PassThrough (already set)
  inspect(
    should_read_body_until_close(200, headers_no_length, PassThrough, None),
    content="false",
  )
}

///|
test "should_read_body_until_close - false cases (CONNECT requests)" {
  let headers_no_length : Map[String, String] = {}

  // Successful CONNECT (2xx) responses become tunnels with no HTTP body
  inspect(
    should_read_body_until_close(200, headers_no_length, Empty, Some(Connect)),
    content="false",
  )

  inspect(
    should_read_body_until_close(201, headers_no_length, Empty, Some(Connect)),
    content="false",
  )

  inspect(
    should_read_body_until_close(299, headers_no_length, Empty, Some(Connect)),
    content="false",
  )

  // Failed CONNECT (non-2xx) should follow normal rules
  // 4xx error responses can have a body
  inspect(
    should_read_body_until_close(400, headers_no_length, Empty, Some(Connect)),
    content="true",
  )

  inspect(
    should_read_body_until_close(502, headers_no_length, Empty, Some(Connect)),
    content="true",
  )
}

///|
test "should_read_body_until_close - false cases (HEAD requests)" {
  let headers_no_length : Map[String, String] = {}

  // HEAD responses never have a message body, regardless of status code
  inspect(
    should_read_body_until_close(200, headers_no_length, Empty, Some(Head)),
    content="false",
  )

  inspect(
    should_read_body_until_close(404, headers_no_length, Empty, Some(Head)),
    content="false",
  )

  inspect(
    should_read_body_until_close(500, headers_no_length, Empty, Some(Head)),
    content="false",
  )

  // Even with Content-Length header, HEAD should not read body
  let headers_with_length : Map[String, String] = { "content-length": "42" }
  inspect(
    should_read_body_until_close(200, headers_with_length, Empty, Some(Head)),
    content="false",
  )
}
