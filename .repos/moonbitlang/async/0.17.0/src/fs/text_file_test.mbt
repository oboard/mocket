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
async test "text file" {
  @async.with_task_group(root => {
    let path = "_build/basic_text_file_test"
    root.add_defer(() => @fs.remove(path))
    @fs.write_file(path, "abcd", create=0o644)
    inspect(@fs.read_file(path).text(), content="abcd")
  })
}
