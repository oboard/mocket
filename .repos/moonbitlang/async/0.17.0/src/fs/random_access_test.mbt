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
async test "write_at" {
  let path = "_build/write_at_test"
  // initialize
  @fs.write_file(path, "abcdef", create=0o644, sync=Full)
  // first read
  inspect(@fs.read_file(path).text(), content="abcdef")
  // update content
  {
    let w = @fs.open(path, mode=WriteOnly)
    defer w.close()
    w.write_at("56", position=w.size() - 2)
    w.write_at("34", position=2)
    w.write("12") // still write from the start
  }
  // read content
  {
    let r = @fs.open(path, mode=ReadOnly)
    defer r.close()
    inspect(r.read_all().text(), content="123456")
  }
  @fs.remove(path)
}

///|
async test "read_at" {
  let path = "_build/read_at_test"
  @fs.write_file(path, "abcdef", create=0o644, sync=Full)
  {
    let r = @fs.open(path, mode=ReadOnly)
    defer r.close()
    json_inspect(r.read_exactly_at(2, position=r.size() - 2), content="ef")
    json_inspect(r.read_exactly_at(2, position=2), content="cd")
    // still read from the start
    json_inspect(r.read_exactly(2), content="ab")
    let buf = FixedArray::make(2, b'\x00')
    let n = r.read_at(buf, position=5)
    inspect(n, content="1")
    json_inspect(buf.unsafe_reinterpret_as_bytes()[:n], content="f")
  }
  @fs.remove(path)
}
