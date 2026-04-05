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
  let args = @env.args()
  match args {
    [] | [_] => @stdio.stdout.write_reader(@stdio.stdin)
    [_, .. files] =>
      for file in files {
        if file == "-" {
          @stdio.stdout.write_reader(@stdio.stdin)
        } else {
          let file = @fs.open(file, mode=ReadOnly)
          defer file.close()
          @stdio.stdout.write_reader(file)
        }
      }
  }
}
