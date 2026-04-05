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
struct OsString(Bytes)

///|
/// Windows uses UTF-16 encoding for various things
#cfg(platform="windows")
struct OsString(String)

///|
#cfg(not(platform="windows"))
pub fn encode(str : StringView) -> OsString {
  @utf8.encode(str)
}

///|
#cfg(platform="windows")
pub fn encode(str : StringView) -> OsString {
  str.to_string()
}

///|
pub impl Show for OsString with output(self, logger) {
  self.to_string().output(logger)
}

///|
#cfg(not(platform="windows"))
pub impl Show for OsString with to_string(self) {
  @utf8.decode_lossy(self.0)
}

///|
#cfg(platform="windows")
pub impl Show for OsString with to_string(self) {
  self.0
}

///|
#cfg(not(platform="windows"))
pub fn decode(os_str : @c_buffer.Buffer) -> String {
  let len = os_str.strlen()
  let data = FixedArray::make(len, b'\x00')
  os_str.blit_to_bytes(dst=data, offset=0, len~)
  @utf8.decode_lossy(data.unsafe_reinterpret_as_bytes())
}

///|
#cfg(platform="windows")
pub extern "C" fn decode(os_str : @c_buffer.Buffer) -> String = "moonbitlang_async_c_buffer_as_string"

///|
#cfg(platform="windows")
let _mute_unused_warning : Unit = ignore(@utf8.encode(""))
