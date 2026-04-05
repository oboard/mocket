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
async test "exists" {
  assert_true(@fs.exists("moon.mod.json"))
  @fs.open("moon.mod.json", mode=ReadOnly).close()
  assert_false(@fs.exists("moon.mod.json.not_exist"))
  try @fs.open("moon.mod.json.not_exist", mode=ReadOnly) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => ()
    err => fail("incorrect error: \{err}")
  } noraise {
    file => {
      file.close()
      fail("`@fs.open` succeed unexpectedly")
    }
  }
}

///|
async test "can_read" {
  assert_true(@fs.can_read("moon.mod.json"))
}

///|
async test "can_write" {
  assert_true(@fs.can_write("moon.mod.json"))
}

///|
#cfg(not(platform="windows"))
async test "can_execute" {
  assert_false(@fs.can_execute("moon.mod.json"))
}

///|
#cfg(not(platform="windows"))
async test "chmod" {
  let path = "_build/chmod_test"
  @async.with_task_group(group => {
    @fs.write_file(path, "abcd", create=0o444)
    group.add_defer(() => @fs.remove(path))
    inspect(@fs.can_read(path), content="true")
    inspect(@fs.can_write(path), content="false")
    inspect(@fs.can_execute(path), content="false")
    @fs.chmod(path, 0o644)
    inspect(@fs.can_read(path), content="true")
    inspect(@fs.can_write(path), content="true")
    inspect(@fs.can_execute(path), content="false")
    @fs.chmod(path, 0o755)
    inspect(@fs.can_read(path), content="true")
    inspect(@fs.can_write(path), content="true")
    inspect(@fs.can_execute(path), content="true")
  })
}
