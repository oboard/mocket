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
async test "walk sequential" {
  let dirs = []
  @fs.walk("test_directory", max_concurrency=1, (path, files) => {
    files.sort()
    dirs.push((path, files))
  })
  json_inspect(dirs, content=[
    ["test_directory", ["file", "inner1"]],
    ["test_directory/inner1", ["file", "inner2"]],
    ["test_directory/inner1/inner2", ["file"]],
  ])
}

///|
async test "walk parallel" {
  @async.sleep(300)
  let log = StringBuilder::new()
  let mut i = 0
  @fs.walk("test_directory", max_concurrency=2, (path, _) => {
    i = i + 1
    log.write_string("handling \{path}\n")
    @async.sleep(if i == 1 { 200 } else { 300 })
    log.write_string("finished handling \{path}\n")
  })
  inspect(
    log.to_string(),
    content=(
      #|handling test_directory
      #|handling test_directory/inner1
      #|finished handling test_directory
      #|handling test_directory/inner1/inner2
      #|finished handling test_directory/inner1
      #|finished handling test_directory/inner1/inner2
      #|
    ),
  )
}

///|
async test "walk failure" {
  let log = StringBuilder::new()
  inspect(
    try? @fs.walk("test_directory", max_concurrency=1, (path, _) => {
      log.write_string("handling \{path}\n")
      raise Failure::Failure("failure when handling directory")
    }),
    content=(
      #|Err(Failure("failure when handling directory"))
    ),
  )
  inspect(
    log,
    content=(
      #|handling test_directory
      #|
    ),
  )
}

///|
async test "walk allow_failure" {
  let log = StringBuilder::new()
  inspect(
    try? @fs.walk("test_directory", allow_failure=true, max_concurrency=1, (
      path,
      _,
    ) => {
      log.write_string("handling \{path}\n")
      raise Failure::Failure("failure when handling directory")
    }),
    content="Ok(())",
  )
  inspect(
    log,
    content=(
      #|handling test_directory
      #|handling test_directory/inner1
      #|handling test_directory/inner1/inner2
      #|
    ),
  )
}

///|
async test "walk exclude 1" {
  let walked = []
  @fs.walk("test_directory", exclude=p => p is [.., '1'], (path, _) => {
    walked.push(path)
  })
  json_inspect(walked, content=["test_directory"])
}

///|
async test "walk exclude 2" {
  let walked = []
  @fs.walk("test_directory", exclude=p => p is [.., '2'], (path, _) => {
    walked.push(path)
  })
  json_inspect(walked, content=["test_directory", "test_directory/inner1"])
}
