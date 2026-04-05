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
test "resolve_url" {
  inspect(
    try? resolve_url("http://www.example.org"),
    content=(
      #|Ok((Http, 80, "www.example.org", "/"))
    ),
  )
  inspect(
    try? resolve_url("http://www.example.org/path/to"),
    content=(
      #|Ok((Http, 80, "www.example.org", "/path/to"))
    ),
  )
  inspect(
    try? resolve_url("https://www.example.org/path/to?search=q"),
    content=(
      #|Ok((Https, 443, "www.example.org", "/path/to?search=q"))
    ),
  )
  inspect(
    try? resolve_url("ftp://www.example.org"),
    content=(
      #|Err(UnsupportedProtocol("ftp"))
    ),
  )
  inspect(
    try? resolve_url("http://www.example.org:10042"),
    content=(
      #|Ok((Http, 10042, "www.example.org", "/"))
    ),
  )
  inspect(
    try? resolve_url("http://www.example.org:10042/path"),
    content=(
      #|Ok((Http, 10042, "www.example.org", "/path"))
    ),
  )
  inspect(
    try? resolve_url("http://www.example.org:0"),
    content="Err(InvalidFormat)",
  )
  inspect(
    try? resolve_url("http://www.example.org:100042"),
    content="Err(InvalidFormat)",
  )
}
