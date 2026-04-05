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

/// Tests for public WebSocket API

///|
test "CloseCode conversions" {
  assert_eq(CloseCode::Normal.to_uint16(), 1000)
  assert_eq(CloseCode::GoingAway.to_uint16(), 1001)
  assert_eq(CloseCode::ProtocolError.to_uint16(), 1002)
  assert_eq(CloseCode::UnsupportedData.to_uint16(), 1003)
  assert_eq(CloseCode::InvalidFramePayload.to_uint16(), 1007)
  assert_eq(CloseCode::PolicyViolation.to_uint16(), 1008)
  assert_eq(CloseCode::MessageTooBig.to_uint16(), 1009)
  assert_eq(CloseCode::InternalError.to_uint16(), 1011)
  assert_eq(CloseCode::from_uint(1000), CloseCode::Normal)
  assert_eq(CloseCode::from_uint(1001), CloseCode::GoingAway)
  assert_eq(CloseCode::from_uint(1002), CloseCode::ProtocolError)
  assert_eq(CloseCode::from_uint(1003), CloseCode::UnsupportedData)
  assert_eq(CloseCode::from_uint(1007), CloseCode::InvalidFramePayload)
  assert_eq(CloseCode::from_uint(1008), CloseCode::PolicyViolation)
  assert_eq(CloseCode::from_uint(1009), CloseCode::MessageTooBig)
  assert_eq(CloseCode::from_uint(1011), CloseCode::InternalError)
}
