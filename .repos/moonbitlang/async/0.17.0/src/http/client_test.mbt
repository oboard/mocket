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
#cfg(target="native")
async fn test_server(group : @async.TaskGroup[Unit], log : &Logger) -> Int {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((request, body, conn) => {
      let meth = request.meth.to_string().to_upper()
      log.write_string("server received request: \{meth} \{request.path}\n")
      while body.read_some() is Some(data) {
        let data = @utf8.decode(data)
        log.write_string("server received: \{data}")
      }
      conn.send_response(200, "OK")
      log.write_string("server: sending \{meth} response part 1\n")
      conn..write("\{meth} response part 1\n").flush()
      @async.sleep(100)
      log.write_string("server: sending \{meth} response part 2\n")
      conn.write("\{meth} response part 2\n")
    })
  })
  server.addr.port()
}

///|
#cfg(target="js")
#external
type Server

///|
#cfg(target="js")
extern "js" fn Server::close(server : Server) =
  #| (server) => server.close()

///|
#cfg(target="js")
extern "js" fn Server::port(server : Server) -> Int =
  #| (server) => server.address().port

///|
#cfg(target="js")
extern "js" fn Server::create(
  logger : (String) -> Unit,
) -> @js_async.Promise[Server] =
  #| (logger) => {
  #|   const http = require('node:http')
  #|   const server = http.createServer()
  #|   server.on('request', (req, response) => {
  #|     logger(`server received request: ${req.method} ${req.url}\n`)
  #|     req.on('data', (data) => {
  #|       logger(`server received: ${data}`)
  #|     })
  #|     req.on('end', () => {
  #|       response.statusCode  = 200
  #|       response.statusMessage = "OK"
  #|       logger(`server: sending ${req.method} response part 1\n`)
  #|       response.write(`${req.method} response part 1\n`, () => {
  #|         setTimeout(() => {
  #|           logger(`server: sending ${req.method} response part 2\n`)
  #|           response.end(`${req.method} response part 2\n`)
  #|         }, 100)
  #|       })
  #|     })
  #|   })
  #|   server.listen(0, '127.0.0.1')
  #|   return new Promise((resolve) => {
  #|     server.on('listening', () => resolve(server))
  #|   })
  #| }

///|
#cfg(target="js")
async fn test_server(group : @async.TaskGroup[Unit], log : &Logger) -> Int {
  let server = Server::create(msg => log.write_string(msg)).wait()
  group.add_defer(() => server.close())
  server.port()
}

///|
async test "request streaming" {
  let log = StringBuilder::new()
  @async.with_task_group(group => {
    let port = test_server(group, log)
    async fn fetch_response(client : @http.Client) {
      while client.read_some() is Some(data) {
        let data = @utf8.decode(data)
        log.write_string("client received: \{data}")
      }
    }

    {
      log.write_string("client sending GET request\n")
      let (response, client) = @http.get_stream("http://localhost:\{port}/get")
      defer client.close()
      inspect(response.code, content="200")
      fetch_response(client)
    }
    {
      log.write_string("client sending PUT request\n")
      let client = @http.put_stream("http://localhost:\{port}/put")
      defer client.close()
      @async.sleep(100)
      log.write_string("client: sending PUT data part 1\n")
      client..write("PUT data part 1\n").flush()
      @async.sleep(100)
      log.write_string("client: sending PUT data part 2\n")
      client.write("PUT data part 2\n")
      let response = client.end_request()
      inspect(response.code, content="200")
      fetch_response(client)
    }
    {
      log.write_string("client sending POST request\n")
      let client = @http.post_stream("http://localhost:\{port}/post")
      defer client.close()
      @async.sleep(100)
      log.write_string("client: sending POST data part 1\n")
      client..write("POST data part 1\n").flush()
      @async.sleep(100)
      log.write_string("client: sending POST data part 2\n")
      client.write("POST data part 2\n")
      let response = client.end_request()
      inspect(response.code, content="200")
      fetch_response(client)
    }
    // give some time for the client to close,
    // so that the port occupied by the server can be reused immediately.
    @async.sleep(200)
  })
  inspect(
    log,
    content=(
      #|client sending GET request
      #|server received request: GET /get
      #|server: sending GET response part 1
      #|client received: GET response part 1
      #|server: sending GET response part 2
      #|client received: GET response part 2
      #|client sending PUT request
      #|client: sending PUT data part 1
      #|server received request: PUT /put
      #|server received: PUT data part 1
      #|client: sending PUT data part 2
      #|server received: PUT data part 2
      #|server: sending PUT response part 1
      #|client received: PUT response part 1
      #|server: sending PUT response part 2
      #|client received: PUT response part 2
      #|client sending POST request
      #|client: sending POST data part 1
      #|server received request: POST /post
      #|server received: POST data part 1
      #|client: sending POST data part 2
      #|server received: POST data part 2
      #|server: sending POST response part 1
      #|client received: POST response part 1
      #|server: sending POST response part 2
      #|client received: POST response part 2
      #|
    ),
  )
}

///|
async test "multiple request" {
  let client = @http.Client("https://www.moonbitlang.com")
  defer client.close()
  let response1 = client.get("/")
  inspect(response1.code, content="200")
  assert_true(client.read_all().text().has_prefix("<!doctype html>"))
  let response2 = client.get("/download")
  inspect(response2.code, content="200")
  assert_true(client.read_all().text().has_prefix("<!doctype html>"))
}
