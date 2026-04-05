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
async fn main {
  let out_channel = Ref::new(@stdio.stdout)
  let timeout = Ref::new(None)
  loop @env.args()[1:] {
    ["-stderr", ..rest] => {
      out_channel.val = @stdio.stderr
      continue rest
    }
    ["-stdout", ..rest] => {
      out_channel.val = @stdio.stdout
      continue rest
    }
    ["-timeout", ..rest] => {
      guard rest is [t, ..rest] else {
        fail("invalid argument")
      }
      timeout.val = Some(@string.parse_int(t))
      continue rest 
    }
    [] => ()
    _ => fail("invalid arguments")
  }
  async fn work() {
    out_channel.val.write_reader(@stdio.stdin)
  }
  if timeout.val is Some(t) {
    @async.with_timeout(t, work)
  } else {
    work()
  }
}
