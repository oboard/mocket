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
/// Get the current wall-clock time in milliseconds.
///
/// This is the time source used by the async runtime. It is intended for
/// computing elapsed time by subtraction. The value can jump forwards or
/// backwards if the system clock is adjusted, so do not assume monotonicity.
///
/// Platform notes:
/// - Unix/macOS: `gettimeofday()` (Unix epoch)
/// - Windows: `GetSystemTimeAsFileTime()` (FILETIME epoch, 1601)
/// - JavaScript: `Date.getTime()` (Unix epoch)
///
/// # Example
/// ```mbt check
/// test {
///   let _ : Int64 = ms_since_epoch()
/// }
/// ```
#cfg(target="native")
pub extern "C" fn ms_since_epoch() -> Int64 = "moonbitlang_async_get_ms_since_epoch"

///|
#cfg(target="js")
extern "js" fn js_now() -> Double =
  #| () => (new Date()).getTime()

///|
/// Get the current wall-clock time in milliseconds.
///
/// This is the time source used by the async runtime. It is intended for
/// computing elapsed time by subtraction. The value can jump forwards or
/// backwards if the system clock is adjusted, so do not assume monotonicity.
///
/// Platform notes:
/// - Unix/macOS: `gettimeofday()` (Unix epoch)
/// - Windows: `GetSystemTimeAsFileTime()` (FILETIME epoch, 1601)
/// - JavaScript: `Date.getTime()` (Unix epoch)
///
/// # Example
/// ```mbt check
/// test {
///   let _ : Int64 = ms_since_epoch()
/// }
/// ```
#cfg(target="js")
pub fn ms_since_epoch() -> Int64 {
  js_now().to_int64()
}

///|
#cfg(any(target="wasm", target="wasm-gc"))
pub fn ms_since_epoch() -> Int64 {
  abort("unimplemented")
}
