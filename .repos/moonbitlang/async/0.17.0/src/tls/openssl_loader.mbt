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
#borrow(major, minor, fix)
extern "C" fn load_openssl_ffi(
  major : Ref[Int],
  minor : Ref[Int],
  fix : Ref[Int],
) -> Int = "moonbitlang_async_load_openssl"

///|
#cfg(not(platform="windows"))
extern "C" fn init_bio_method(
  read : FuncRef[(BIO, @c_buffer.Buffer, Int) -> Int],
  write : FuncRef[(BIO, @c_buffer.Buffer, Int) -> Int],
) = "moonbitlang_async_init_bio_method"

///|
#cfg(not(platform="windows"))
let openssl_loaded : Ref[Bool] = Ref::new(false)

///|
#cfg(not(platform="windows"))
fn load_openssl() -> Unit {
  if openssl_loaded.val {
    return
  }
  openssl_loaded.val = true
  let major = Ref::new(0)
  let minor = Ref::new(0)
  let fix = Ref::new(0)
  match load_openssl_ffi(major, minor, fix) {
    0 => ()
    1 => abort("failed to load OpenSSL")
    2 => abort("failed to get OpenSSL version")
    3 =>
      abort("unsupported OpenSSL version \{major.val}.\{minor.val}.\{fix.val}")
    4 => abort("failed to load some OpenSSL function")
    _ => panic()
  }
}

///|
#cfg(not(platform="windows"))
fn init {
  load_openssl()
  init_bio_method((bio, dst, len) => bio.read(dst, len), (bio, src, len) => {
    bio.write(src, len)
  })
}
