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
let _ignore_unused_import : Unit = {
  ignore(@c_buffer.unimplemented)
  ignore(@fd_util.unimplemented)
  ignore(@os_string.unimplemented)
  ignore(@os_error.unimplemented)
  ignore(@time.ms_since_epoch)
}

///|
pub fn reschedule() -> Unit {
  guard !@coroutine.no_more_work() else {  }
  @coroutine.reschedule()
  // Instead of looping blockingly until there is no ready task,
  // we only perform one round of scheduling here
  // (i.e., only those tasks already ready when `reschedule` is called are run).
  // Remaining tasks are delayed untin the next js event loop,
  // so that those blocking jobs got a chance to execute instead of starving.
  if @coroutine.has_immediately_ready_task() {
    ignore(set_timeout(0, reschedule))
  }
}
