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
async test "read_all" {
  let dir = @fs.opendir("src/fs")
  defer dir.close()
  let list = dir
    .read_all()
    .filter_map(x => if x is "target" { None } else { Some(x) })
  list.sort()
  json_inspect(list, content=[
    "stub.c", "dir.mbt", "file.mbt", "moon.pkg", "README.md", "utils.mbt", "tmpdir.mbt",
    "dir_test.mbt", "eof_test.mbt", "README.mbt.md", "constants.mbt", "lock_test.mbt",
    "stat_test.mbt", "walk_test.mbt", "mkdir_test.mbt", "access_test.mbt", "create_test.mbt",
    "tmpdir_test.mbt", "read_all_test.mbt", "realpath_test.mbt", "unimplemented.mbt",
    "pkg.generated.mbti", "text_file_test.mbt", "timestamp_test.mbt", "named_pipe_test.mbt",
    "random_access_test.mbt", "unimplemented_test.mbt",
  ])
}

///|
#cfg(not(platform="windows"))
#warnings("-deprecated")
async test "as_dir" {
  let dir_file = @fs.open("src/fs", mode=ReadOnly)
  guard dir_file.kind() is Directory
  let dir = dir_file.as_dir()
  defer dir.close()
  let list = dir
    .read_all()
    .filter_map(x => if x is "target" { None } else { Some(x) })
  list.sort()
  let kinds = []
  for file in list {
    let path = "src/fs/" + file
    let kind = {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      file.kind()
    }
    assert_eq(kind, @fs.kind(path))
    kinds.push("\{file}: \{kind}")
  }
  json_inspect(kinds, content=[
    "stub.c: Regular", "dir.mbt: Regular", "file.mbt: Regular", "moon.pkg: Regular",
    "README.md: Regular", "utils.mbt: Regular", "tmpdir.mbt: Regular", "dir_test.mbt: Regular",
    "eof_test.mbt: Regular", "README.mbt.md: Regular", "constants.mbt: Regular",
    "lock_test.mbt: Regular", "stat_test.mbt: Regular", "walk_test.mbt: Regular",
    "mkdir_test.mbt: Regular", "access_test.mbt: Regular", "create_test.mbt: Regular",
    "tmpdir_test.mbt: Regular", "read_all_test.mbt: Regular", "realpath_test.mbt: Regular",
    "unimplemented.mbt: Regular", "pkg.generated.mbti: Regular", "text_file_test.mbt: Regular",
    "timestamp_test.mbt: Regular", "named_pipe_test.mbt: Regular", "random_access_test.mbt: Regular",
    "unimplemented_test.mbt: Regular",
  ])
}

///|
test "readdir clear errno" {
  @event_loop.with_event_loop(() => {
    // do something to set a non-zero errno
    try @fs.open("/this/file/does/not/exist", mode=ReadOnly) catch {
      _ => ()
    } noraise {
      _ => ()
    }
    let dir = @fs.opendir("src/fs")
    defer dir.close()
    let list = dir.read_all()
    inspect(
      list.length(),
      content=(
        #|27
      ),
    )
  })
}
