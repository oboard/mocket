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
let cat : @async.Lazy[String] = @async.Lazy(() => {
  // Note: the `cat` example program lies in another MoonBit module.
  // Currently, dependencies of a module is built locally in that module,
  // so there will be no build lock conflict between this test and the `cat` program.
  let exit_code = @process.run("moon", [
    "build", "--manifest-path", "src/process/test_programs/moon.mod.json", "--debug",
    "src/process/test_programs/cat",
  ])
  guard exit_code is 0 else {
    fail("failed to build `cat` program: \{exit_code}")
  }
  "./src/process/test_programs/_build/native/debug/build/cat/cat.exe"
})

///|
async test "redirect_file" {
  let cat = cat.wait()
  let out_file = "_build/stdio_file_test"
  let code = @process.run(
    cat,
    [],
    stdin=@process.redirect_from_file("moon.mod.json"),
    stdout=@process.redirect_to_file(out_file, create=0o644),
  )
  inspect(code, content="0")
  assert_eq(
    @fs.read_file(out_file).text(),
    @fs.read_file("moon.mod.json").text(),
  )
}

///|
async test "redirect pipe" {
  @async.with_task_group(root => {
    let cat = cat.wait()
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    root.spawn_bg(() => {
      let code = @process.run(cat, [], stdin=cat_read, stdout=cat_write)
      inspect(code, content="0")
    })
    root.spawn_bg(() => {
      defer we_write.close()
      we_write.write(b"abcd\n")
      @async.sleep(50)
      we_write.write(b"defg\n")
    })
    defer we_read.close()
    inspect(
      we_read.read_all().text(),
      content=(
        #|abcd
        #|defg
        #|
      ),
    )
  })
}

///|
async test "stdio cancel" {
  let cat = cat.wait()
  @async.with_task_group(group => {
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    group.spawn_bg(() => {
      let code = @process.run(
        cat,
        ["-timeout", "500"],
        stdin=cat_read,
        stdout=cat_write,
      )
      inspect(code, content="1")
    })
    defer we_write.close()
    defer we_read.close()
    we_write.write("abcd")
    inspect(
      we_read.read_some(),
      content=(
        #|Some(b"abcd")
      ),
    )
    @async.sleep(750)
    inspect(
      we_read.read_all().text().trim(chars="\r\n"),
      content="TimeoutError",
    )
  })
}
