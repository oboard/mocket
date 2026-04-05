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
fn output_response(response : @http.Response, logger : &Logger) -> Unit {
  logger.write_string("HTTP/1.1 \{response.code} \{response.reason}\n")
  for k, v in response.headers {
    logger.write_string("\{k}: \{v}\n")
  }
}

///|
async fn client(
  addr : @socket.Addr,
  path : String,
  logger : &Logger,
  handle_response? : async (@http.Client) -> Unit,
) -> Unit {
  let conn = @http.Client("http://localhost:\{addr.port()}")
  defer conn.close()
  let response = conn.get(path)
  output_response(response, logger)
  match handle_response {
    None => logger.write_string(conn.read_all().text())
    Some(f) => f(conn)
  }
}

///|
async test "basic" {
  fn log(_) -> Unit {

  }

  let client_log = StringBuilder::new()
  @async.with_task_group(root => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    root.spawn_bg(no_wait=true, () => server_main(server, path=".", log~))
    @async.sleep(50)
    client_log.write_string("client: GET /examples/http_file_server\n")
    client(addr, "/examples/http_file_server", client_log)
    client_log.write_string("\n\n")
    client_log.write_string("client: GET /examples/moon.mod.json\n")
    client(addr, "/examples/moon.mod.json", client_log)
    client_log.write_string("\n\n")
    let tmp_file_name = "examples/test.zip"
    let tmp_file = @fs.create(tmp_file_name, permission=0o644)
    root.add_defer(() => @fs.remove(tmp_file_name))
    client(addr, "/examples/http_file_server?download_zip", client_log, handle_response=body => {
      tmp_file.write_reader(body)
    })
    tmp_file.close()
    let (from_unzip, w) = @process.read_from_process()
    defer from_unzip.close()
    if is_windows {
      @process.spawn(root, "tar", ["-t", "-f", tmp_file_name], stdout=w)
      |> ignore
    } else {
      @process.spawn(root, "unzip", ["-l", tmp_file_name], stdout=w) |> ignore
    }
    let zip_content = []
    for i = 0; ; i = i + 1 {
      if is_windows {
        guard from_unzip.read_until("\r\n") is Some(line) else { break }
        let name = if line is [.. "./", .. name] {
          name.to_string()
        } else {
          line
        }
        zip_content.push(name)
      } else {
        guard from_unzip.read_until("\n") is Some(line) else { break }
        guard line.rev_find(" ") is Some(i) else {
          fail("invalid output from `unzip`")
        }
        let last_word = line[i + 1:]
        if last_word.has_prefix("examples/http_file_server") {
          zip_content.push(last_word.to_string())
        }
      }
    }
    zip_content.sort()
    for file in zip_content {
      client_log..write_string(file).write_string("\n")
    }
  })
  inspect(
    client_log,
    content=(
      #|client: GET /examples/http_file_server
      #|HTTP/1.1 200 OK
      #|content-type: text/html
      #|transfer-encoding: chunked
      #|<!DOCTYPE html><html><head></head><body><h1>/examples/http_file_server</h1>
      #|<div style="margin: 1em; font-size: 15pt"><a href="/examples/http_file_server?download_zip">download as zip</a><br/><br/>
      #|<a href="/examples">..</a><br/><br/>
      #|<a href="/examples/http_file_server/main.mbt">main.mbt</a><br/>
      #|<a href="/examples/http_file_server/moon.pkg">moon.pkg</a><br/>
      #|<a href="/examples/http_file_server/server_wbtest.mbt">server_wbtest.mbt</a><br/>
      #|<a href="/examples/http_file_server/pkg.generated.mbti">pkg.generated.mbti</a><br/>
      #|</div></body></html>
      #|
      #|client: GET /examples/moon.mod.json
      #|HTTP/1.1 200 OK
      #|content-type: appliaction/octet-stream
      #|transfer-encoding: chunked
      #|{
      #|  "name": "moonbitlang/async_examples",
      #|  "version": "0.3.0",
      #|  "deps": {
      #|    "moonbitlang/async": {
      #|      "path": ".."
      #|    }
      #|  },
      #|  "readme": "README.md",
      #|  "repository": "https://github.com/moonbitlang/async",
      #|  "license": "Apache-2.0",
      #|  "keywords": [],
      #|  "description": "Examples for `moonbitlang/async`",
      #|  "source": ".",
      #|  "preferred-target": "native"
      #|}
      #|
      #|
      #|HTTP/1.1 200 OK
      #|content-type: application/octet-stream
      #|content-disposition: filename=http_file_server.zip
      #|transfer-encoding: chunked
      #|examples/http_file_server/
      #|examples/http_file_server/main.mbt
      #|examples/http_file_server/moon.pkg
      #|examples/http_file_server/server_wbtest.mbt
      #|examples/http_file_server/pkg.generated.mbti
      #|
    ),
  )
}
