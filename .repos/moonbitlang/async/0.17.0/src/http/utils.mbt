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
fn encode_int(value : Int, base~ : Int) -> Bytes {
  let len = for x = value, len = 1; x >= base; {
    continue x / base, len + 1
  } nobreak {
    len
  }
  let out = FixedArray::make(len, b'0')
  for x = value, i = len - 1; i >= 0; x = x / base, i = i - 1 {
    let digit = x % base
    let chr = if digit < 10 { digit + '0' } else { digit - 10 + 'a' }
    out[i] = chr.to_byte()
  }
  out.unsafe_reinterpret_as_bytes()
}
