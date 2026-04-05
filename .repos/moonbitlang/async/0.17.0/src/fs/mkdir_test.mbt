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
async test "mkdir" {
  let path = "_build/mkdir_test"
  @fs.mkdir(path, permission=0o755)
  @fs.write_file("\{path}/file", "", create=0o644)
  let result = @fs.readdir(path, sort=true)
  @fs.remove("\{path}/file")
  @fs.rmdir(path)
  inspect(result, content="[\"file\"]")
}

///|
#cfg(not(platform="windows"))
async test "rmdir recursive" {
  let path = "_build/rmdir_test"
  @fs.mkdir(path, permission=0o755)
  @fs.write_file("\{path}/file", "", create=0o644)
  @fs.mkdir("\{path}/inner", permission=0o755)
  @fs.write_file("\{path}/inner/file", "", create=0o644)
  @fs.symlink("\{path}/symlink", target="../../target")
  let result = try? @fs.rmdir(path)
  @fs.rmdir(path, recursive=true)
  assert_true(result is Err(_))
}

///|
async test "mkdir recursive" {
  @async.with_task_group(group => {
    let base_path = "_build/recursive_mkdir"
    let path = "\{base_path}/test//directory"
    @fs.mkdir(path, permission=0o755, recursive=true)
    group.add_defer(() => @fs.rmdir(base_path, recursive=true))
    json_inspect(@fs.readdir(base_path), content=["test"])
    json_inspect(@fs.readdir("\{base_path}/test"), content=["directory"])
    json_inspect(@fs.readdir("\{base_path}/test/directory"), content=[])
  })
}

///|
#cfg(platform="windows")
async test "mkdir recursive windows" {
  @async.with_task_group(group => {
    let base_path = "target\\recursive_mkdir_windows"
    let path = "\{base_path}\\test\\\\directory"
    @fs.mkdir(path, permission=0o755, recursive=true)
    group.add_defer(() => @fs.rmdir(base_path, recursive=true))
    json_inspect(@fs.readdir(base_path), content=["test"])
    json_inspect(@fs.readdir("\{base_path}\\test"), content=["directory"])
    json_inspect(@fs.readdir("\{base_path}\\test/directory"), content=[])
  })
}
