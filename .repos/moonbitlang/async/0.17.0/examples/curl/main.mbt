///|
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
let help_message : String =
  #|Usage: curl OPTION URL
  #|Download content of URL
  #|
  #|Options:
  #|  -o FILE       write output to FILE instead of standard output
  #|  --proxy URL   download via HTTP proxy PROXY
  #|  -h, --help    show this message

///|
async fn download(
  url : String,
  proxy~ : String?,
  output~ : &@io.Writer,
) -> Unit {
  let proxy = match proxy {
    None => None
    Some(proxy_url) => Some(@http.Client(proxy_url))
  }
  let (_response, body) = @http.get_stream(url, proxy?)
  defer body.close()
  output.write_reader(body)
}

///|
async fn main {
  let mut url = None
  let mut output = None
  let mut proxy = None
  loop @env.args()[1:] {
    ["-o", .. rest] => {
      guard rest is [file, .. rest] else {
        fail("expected output file after `-o`")
      }
      output = Some(file)
      continue rest
    }
    ["--proxy", .. rest] => {
      guard rest is [url, .. rest] else {
        fail("expected proxy URL after `--proxy`")
      }
      proxy = Some(url)
      continue rest
    }
    ["-h" | "--help", ..] => {
      println(help_message)
      return
    }
    [['-', ..] as opt, ..] => fail("unknown option `\{opt}`")
    [url_str, .. rest] => {
      if url is Some(_) {
        fail("too many arguments specified")
      }
      url = Some(url_str)
      continue rest
    }
    [] => ()
  }
  guard url is Some(url) else { fail("no URL specified") }
  match output {
    None => download(url, proxy~, output=@stdio.stdout)
    Some(output) => {
      let file = @fs.open(output, mode=WriteOnly, create=0o644, truncate=true)
      defer file.close()
      download(url, proxy~, output=file)
    }
  }
}
