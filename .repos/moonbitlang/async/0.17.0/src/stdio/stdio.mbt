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
struct Input {
  io : @event_loop.IoHandle
  read_buf : @io.ReaderBuffer
}

///|
pub fn Input::fd(self : Input) -> @fd_util.Fd {
  self.io.fd()
}

///|
pub impl @io.Reader for Input with _direct_read(self, buf, offset~, max_len~) {
  self.io.read(buf, offset~, len=max_len, context="@stdio.Input::read()")
}

///|
pub impl @io.Reader for Input with _get_internal_buffer(self) {
  self.read_buf
}

///|
struct Output(@event_loop.IoHandle)

///|
pub fn Output::fd(self : Output) -> @fd_util.Fd {
  self.0.fd()
}

///|
pub impl @io.Writer for Output with write_once(self, buf, offset~, len~) {
  self.0.write(buf, offset~, len~, context="@fs.File::write()")
}

///|
/// The standard input channel.
/// Using this value will result in standard input being set to non-blocking mode.
/// The standard input will be reset to its original state after the program exits.
pub let stdin : Input = {
  io: @event_loop.stdin,
  read_buf: @io.ReaderBuffer::new(),
}

///|
/// The standard output channel.
/// Using this value will result in standard output being set to non-blocking mode.
/// The standard output will be reset to its original state after the program exits.
pub let stdout : Output = @event_loop.stdout

///|
/// The standard error channel.
/// Using this value will result in standard error being set to non-blocking mode.
/// The standard error will be reset to its original state after the program exits.
pub let stderr : Output = @event_loop.stderr
