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
fn diff_timestamp(t1 : (Int64, Int), t2 : (Int64, Int)) -> Int64 {
  let (s1, ns1) = t1
  let (s2, ns2) = t2
  (s1 - s2) * 1_000_000_000 + (ns1 - ns2).to_int64()
}

///|
#cfg(not(platform="windows"))
async test "timestamp for path" {
  let path = "/tmp/timestamp_test"
  @async.with_task_group(group => {
    @fs.write_file(path, "abcd", create=0o644, sync=Full)
    group.add_defer(() => @fs.remove(path))
    let mtime_1 = @fs.mtime(path)
    let ctime_1 = @fs.ctime(path)
    @async.sleep(600)
    @fs.write_file(path, "1234", sync=Full)
    let atime_2 = @fs.atime(path)
    let mtime_2 = @fs.mtime(path)
    let ctime_2 = @fs.ctime(path)
    assert_true(diff_timestamp(mtime_2, mtime_1) > 500_000_000)
    assert_true(diff_timestamp(ctime_2, ctime_1) > 500_000_000)
    @async.sleep(600)
    inspect(@fs.read_file(path, sync_timestamp=true).text(), content="1234")
    let atime_3 = @fs.atime(path)
    let mtime_3 = @fs.mtime(path)
    let ctime_3 = @fs.ctime(path)
    assert_true(diff_timestamp(atime_3, atime_2) > 500_000_000)
    assert_eq(mtime_3, mtime_2)
    assert_eq(ctime_3, ctime_2)
    @async.sleep(600)
    @fs.chmod(path, 0o666)
    let mtime_4 = @fs.mtime(path)
    let ctime_4 = @fs.ctime(path)
    assert_eq(mtime_4, mtime_3)
    assert_true(diff_timestamp(ctime_4, ctime_3) > 500_000_000)
  })
}

///|
// `atime` is not reliable on Windows.
#cfg(platform="windows")
async test "mtime for path" {
  let path = "_build/timestamp_test"
  @async.with_task_group(group => {
    @fs.write_file(path, "abcd", create=0o644, sync=Full)
    group.add_defer(() => @fs.remove(path))
    let mtime_1 = @fs.mtime(path)
    let ctime_1 = @fs.ctime(path)
    @async.sleep(600)
    @fs.write_file(path, "1234", sync=Full)
    let mtime_2 = @fs.mtime(path)
    let ctime_2 = @fs.ctime(path)
    assert_true(diff_timestamp(mtime_2, mtime_1) > 500_000_000)
    assert_true(diff_timestamp(ctime_2, ctime_1) > 500_000_000)
  })
}

///|
#cfg(not(platform="windows"))
async test "timestamp for opened file" {
  let path = "/tmp/opened_file_timestamp_test"
  @async.with_task_group(group => {
    @fs.write_file(path, "abcd", create=0o644, sync=Full)
    group.add_defer(() => @fs.remove(path))
    let file = @fs.open(path, mode=ReadWrite, sync=Full)
    defer file.close()
    let mtime_1 = file.mtime()
    let ctime_1 = file.mtime()
    @async.sleep(600)
    file.write_at("1234", position=0)
    let atime_2 = file.atime()
    let mtime_2 = file.mtime()
    let ctime_2 = file.mtime()
    assert_true(diff_timestamp(mtime_2, mtime_1) > 500_000_000)
    assert_true(diff_timestamp(ctime_2, ctime_1) > 500_000_000)
    @async.sleep(600)
    inspect(file.read_all().text(), content="1234")
    file.sync()
    let atime_3 = file.atime()
    let mtime_3 = file.mtime()
    let ctime_3 = file.mtime()
    assert_true(diff_timestamp(atime_3, atime_2) > 500_000_000)
    assert_eq(mtime_3, mtime_2)
    assert_eq(ctime_3, ctime_2)
    @async.sleep(600)
    @fs.chmod(path, 0o666)
    let mtime_4 = @fs.mtime(path)
    let ctime_4 = @fs.ctime(path)
    assert_eq(mtime_4, mtime_3)
    assert_true(diff_timestamp(ctime_4, ctime_3) > 500_000_000)
  })
}

///|
// `atime` is not reliable on Windows.
#cfg(platform="windows")
async test "mtime for opened file" {
  let path = "_build/opened_file_timestamp_test"
  @async.with_task_group(group => {
    @fs.write_file(path, "abcd", create=0o644, sync=Full)
    group.add_defer(() => @fs.remove(path))
    let file = @fs.open(path, mode=ReadWrite, sync=Full)
    defer file.close()
    let mtime_1 = file.mtime()
    let ctime_1 = file.mtime()
    @async.sleep(600)
    file.write_at("1234", position=0)
    let mtime_2 = file.mtime()
    let ctime_2 = file.mtime()
    assert_true(diff_timestamp(mtime_2, mtime_1) > 500_000_000)
    assert_true(diff_timestamp(ctime_2, ctime_1) > 500_000_000)
  })
}
