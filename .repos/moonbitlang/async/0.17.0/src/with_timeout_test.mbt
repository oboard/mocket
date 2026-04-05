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
async test "with_timeout normal exit" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(300)
        log.write_string("300ms tick\n")
      })
      @async.with_timeout(400, () => {
        @async.sleep(200)
        log.write_string("task finished after 200ms\n")
      })
      log.write_string("main task finished\n")
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|task finished after 200ms
      #|main task finished
      #|300ms tick
      #|Ok(())
    ),
  )
}

///|
async test "with_timeout failure" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      @async.sleep(200)
      log.write_string("200ms tick\n")
    })
    @async.with_timeout(300, () => {
      @async.sleep(100)
      raise Err
    }) catch {
      err => {
        log.write_string("main task fail with \{err}\n")
        raise err
      }
    }
  }) catch {
    err => log.write_object(err)
  }
  inspect(
    log.to_string(),
    content=(
      #|main task fail with Err
      #|Err
    ),
  )
}

///|
async test "with_timeout timeout" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(300)
        log.write_string("300ms tick\n")
      })
      @async.with_timeout(200, () => {
        @async.sleep(400) catch {
          err => {
            log.write_string("task cancelled\n")
            raise err
          }
        }
        log.write_string("task finished\n")
      }) catch {
        err => log.write_string("`with_timeout` fail with \{err}\n")
      }
      log.write_string("main task finished\n")
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|task cancelled
      #|`with_timeout` fail with TimeoutError
      #|main task finished
      #|300ms tick
      #|Ok(())
    ),
  )
}

///|
async test "with_timeout nested1" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(200)
        log.write_string("200ms tick\n")
        @async.sleep(200)
        log.write_string("400ms tick\n")
      })
      @async.with_timeout(300, () => {
        @async.with_timeout(500, () => {
          @async.sleep(2000) catch {
            err => {
              log.write_string("task cancelled\n")
              raise err
            }
          }
          log.write_string("task finished after 2s\n")
        }) catch {
          err => log.write_string("inner `with_timeout` fail with \{err}\n")
        }
      }) catch {
        err => log.write_string("outer `with_timeout` fail with \{err}\n")
      }
      log.write_string("main task finished\n")
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|200ms tick
      #|task cancelled
      #|inner `with_timeout` fail with Cancelled
      #|outer `with_timeout` fail with TimeoutError
      #|main task finished
      #|400ms tick
      #|Ok(())
    ),
  )
}

///|
async test "with_timeout nested2" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(300)
        log.write_string("300ms tick\n")
        @async.sleep(300)
        log.write_string("600ms tick\n")
      })
      @async.with_timeout(750, () => {
        @async.with_timeout(450, () => {
          @async.sleep(2000) catch {
            err => {
              log.write_string("task cancelled\n")
              raise err
            }
          }
          log.write_string("task finished after 2s\n")
        }) catch {
          err => log.write_string("inner `with_timeout` fail with \{err}\n")
        }
      }) catch {
        err => log.write_string("outer `with_timeout` fail with \{err}\n")
      }
      log.write_string("main task finished\n")
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|300ms tick
      #|task cancelled
      #|inner `with_timeout` fail with TimeoutError
      #|main task finished
      #|600ms tick
      #|Ok(())
    ),
  )
}

///|
async test "with_timeout error_on_cancel" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(200)
        log.write_string("200ms tick\n")
      })
      @async.with_timeout(100, () => {
        @async.sleep(2000) catch {
          _ => {
            log.write_string("causing other error on cancellation\n")
            raise Err
          }
        }
        log.write_string("task finished after 2s\n")
      })
      log.write_string("main task finished\n")
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|causing other error on cancellation
      #|Err(Err)
    ),
  )
}

///|
async test "with_timeout error-on-timeout" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(200)
        log.write_string("200ms tick\n")
      })
      defer log.write_string("main task terminates\n")
      @async.with_timeout(100, error=Err, () => {
        @async.sleep(2000) catch {
          err => {
            log.write_string("task cancelled\n")
            raise err
          }
        }
        log.write_string("task finished after 2s\n")
      })
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|task cancelled
      #|main task terminates
      #|Err(Err)
    ),
  )
}

///|
async test "with_timeout_opt normal exit" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(200)
        log.write_string("200ms tick\n")
      })
      log.write_object(
        @async.with_timeout_opt(1000, () => {
          @async.sleep(100)
          log.write_string("task finished after 100ms\n")
          42
        }),
      )
      log.write_char('\n')
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|task finished after 100ms
      #|Some(42)
      #|200ms tick
      #|Ok(())
    ),
  )
}

///|
async test "with_timeout_opt failure" {
  let log = StringBuilder::new()
  @async.with_task_group(root => {
    root.spawn_bg(() => {
      @async.sleep(200)
      log.write_string("200ms tick\n")
    })
    @async.with_timeout(1000, () => {
      @async.sleep(100)
      raise Err
    }) catch {
      err => {
        log.write_string("main task fail with \{err}\n")
        raise err
      }
    }
  }) catch {
    err => log.write_object(err)
  }
  inspect(
    log.to_string(),
    content=(
      #|main task fail with Err
      #|Err
    ),
  )
}

///|
async test "with_timeout_opt timeout" {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(root => {
      root.spawn_bg(() => {
        @async.sleep(200)
        log.write_string("200ms tick\n")
      })
      log.write_object(
        @async.with_timeout_opt(100, () => {
          try @async.sleep(2000) catch {
            err => {
              log.write_string("task cancelled\n")
              raise err
            }
          } noraise {
            _ => {
              log.write_string("task finished after 2s\n")
              42
            }
          }
        }),
      )
      log.write_char('\n')
    }),
  )
  inspect(
    log.to_string(),
    content=(
      #|task cancelled
      #|None
      #|200ms tick
      #|Ok(())
    ),
  )
}
