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
async test "basic create" {
  let path = "_build/basic_create_test"
  {
    let w = @fs.create(path, permission=0o644, sync=Full)
    defer w.close()
    w.write(b"abcd\n")
  }
  let result = {
    let r = @fs.open(path, mode=ReadOnly)
    defer r.close()
    r.read_all().text()
  }
  @fs.remove(path)
  inspect(
    result,
    content=(
      #|abcd
      #|
    ),
  )
}

///|
async test "create or append" {
  let path = "_build/create_append_test"
  async fn add_data(data) {
    let w = @fs.open(path, mode=WriteOnly, create=0o644, sync=Full, append=true)
    defer w.close()
    w.write(data)
  }

  add_data(b"abcd")
  add_data(b"efgh")
  let result = {
    let r = @fs.open(path, mode=ReadOnly)
    defer r.close()
    r.read_all().text()
  }
  @fs.remove(path)
  inspect(result, content="abcdefgh")
}

///|
async test "wrapper test" {
  let path = "_build/fs_wrapper_test"
  @fs.write_file(path, b"abcd", create=0o644)
  let result = @fs.read_file(path).text()
  @fs.remove(path)
  inspect(result, content="abcd")
}
