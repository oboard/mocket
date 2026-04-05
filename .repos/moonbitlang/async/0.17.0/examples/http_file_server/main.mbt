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
async fn serve_directory(
  conn : @http.ServerConnection,
  dir : @fs.Directory,
  path~ : String,
) -> Unit {
  let files = dir.read_all()
  files.sort()
  conn
  ..send_response(200, "OK", extra_headers={ "Content-Type": "text/html" })
  ..write("<!DOCTYPE html><html><head></head><body>")
  ..write("<h1>\{path}</h1>\n")
  ..write("<div style=\"margin: 1em; font-size: 15pt\">")
  .write("<a href=\"\{path}?download_zip\">download as zip</a><br/><br/>\n")
  if path[:-1].rev_find("/") is Some(index) {
    let parent : StringView = if index == 0 { "/" } else { path[:index] }
    conn.write("<a href=\"\{parent}\">..</a><br/><br/>\n")
  }
  for file in files {
    let sep = if path is [.., '/'] { "" } else { "/" }
    conn.write("<a href=\"\{path}\{sep}\{file}\">\{file}</a><br/>\n")
  }
  conn..write("</div></body></html>").end_response()
}

///|
async fn serve_file(
  conn : @http.ServerConnection,
  file_path : String,
  path~ : String,
) -> Unit {
  let file = @fs.open(file_path, mode=ReadOnly)
  defer file.close()
  let content_type = match path {
    [.., .. ".png"] => "image/png"
    [.., .. ".jpg"] | "jpeg" => "image/jpeg"
    [.., .. ".html"] => "text/html"
    [.., .. ".css"] => "text/css"
    [.., .. ".js"] => "text/javascript"
    [.., .. ".mp4"] => "video/mp4"
    [.., .. ".mpv"] => "video/mpv"
    [.., .. ".mpeg"] => "video/mpeg"
    [.., .. ".mkv"] => "video/x-matroska"
    _ => "appliaction/octet-stream"
  }
  conn
  ..send_response(200, "OK", extra_headers={ "Content-Type": content_type })
  ..write_reader(file)
  .end_response()
}

///|
#cfg(platform="windows")
let is_windows : Bool = true

///|
#cfg(not(platform="windows"))
let is_windows : Bool = false

///|
async fn serve_zip(conn : @http.ServerConnection, path : String) -> Unit {
  let full_path = @fs.realpath(path)
  let path_sep = if is_windows { "\\" } else { "/" }
  let base_name = if full_path.rev_find(path_sep) is Some(i) {
    full_path[i + 1:].to_string()
  } else {
    path
  }
  @async.with_task_group(group => {
    let (we_read_from_zip, zip_write_to_us) = @process.read_from_process()
    defer we_read_from_zip.close()
    if is_windows {
      @process.spawn(
        group,
        "tar",
        ["-c", "-z", "-f", "-", path],
        stdout=zip_write_to_us,
      )
      |> ignore
    } else {
      @process.spawn(
        group,
        "zip",
        ["-q", "-r", "-", path],
        stdout=zip_write_to_us,
      )
      |> ignore
    }
    conn
    ..send_response(200, "OK", extra_headers={
      "Content-Type": "application/octet-stream",
      "Content-Disposition": "filename=\{base_name}.zip",
    })
    ..write_reader(we_read_from_zip)
    .end_response()
  })
}

///|
let page_for_404 : Bytes = b"<html><head></head><body>Page Not Found</body></html>"

///|
async fn serve_404(conn : @http.ServerConnection) -> Unit {
  conn
  ..send_response(404, "NotFound", extra_headers={ "Content-Type": "text/html" })
  ..write(page_for_404)
  .end_response()
}

///|
pub async fn server_main(
  server : @http.Server,
  path~ : String,
  log? : (String) -> Unit = println,
) -> Unit {
  let base_path = path
  server.run_forever((request, _body, conn) => {
    let (path, download_zip) = match request.path {
      [.. path, .. "?download_zip"] => (path.to_string(), true)
      path => (path, false)
    }
    log("serving \{path}")
    guard request.meth is Get else { return }
    let full_path = base_path + path
    guard @fs.exists(full_path) else {
      serve_404(conn)
      return
    }
    if @fs.kind(full_path) is Directory {
      if download_zip {
        serve_zip(conn, full_path)
      } else {
        let dir = @fs.opendir(full_path)
        defer dir.close()
        serve_directory(conn, dir, path~)
      }
    } else {
      serve_file(conn, full_path, path~)
    }
  })
}

///|
async fn main {
  let path = match @env.args() {
    [] | [_] => "."
    [_, path, ..] => path
  }
  let server = @http.Server(@socket.Addr::parse("0.0.0.0:8000"))
  server_main(server, path~) catch {
    err => println("server terminate due to \{err}")
  }
}
