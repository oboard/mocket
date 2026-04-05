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
#cfg(not(platform="windows"))
async test "stat" {
  let link_path = "_build/fs_stat_test"
  @fs.symlink(link_path, target="../LICENSE")
  @async.with_task_group(group => {
    group.add_defer(() => @fs.remove(link_path))
    inspect(@fs.kind(link_path), content="Regular")
    inspect(@fs.kind(link_path, follow_symlink=false), content="SymLink")
  })
}
