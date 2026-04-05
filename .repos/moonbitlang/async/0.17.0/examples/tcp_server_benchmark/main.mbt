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
let data : Bytes = Bytes::make(1024, 0)

///|
async fn client(
  rand : @random.Rand,
  dst : @socket.Addr,
  total_conn~ : Int,
  max_concurrent_conn~ : Int,
  conn_duration~ : Int,
) -> (Int64, Double) {
  let mut throughput_sum : Int64 = 0
  let mut latency_sum : Int64 = 0
  @async.with_task_group(group => {
    let mut remaining = total_conn
    for _ in 0..<max_concurrent_conn {
      group.spawn_bg(() => {
        let buf = FixedArray::make(1024, b'0')
        while remaining > 0 {
          remaining -= 1
          @async.sleep(rand.int(limit=conn_duration / 10))
          let conn = @socket.Tcp::connect(dst)
          defer conn.close()
          @async.with_task_group(conn_group => {
            let mut send_count : Int64 = 0
            let mut recv_count : Int64 = 0
            let mut before : Int64 = 0
            conn_group.spawn_loop(no_wait=true, () => {
              if send_count == 0 {
                before = @async.now()
              }
              conn.write(data)
              send_count += data.length().to_int64()
            })
            conn_group.spawn_loop(no_wait=true, () => {
              let n = conn.read(buf)
              if recv_count == 0 {
                latency_sum += @async.now() - before
              }
              recv_count += n.to_int64()
            })
            @async.sleep(conn_duration)
            throughput_sum += (send_count + recv_count) *
              1000 /
              conn_duration.to_int64()
          })
        }
      })
    }
  })
  (
    throughput_sum / total_conn.to_int64(),
    latency_sum.to_double() / total_conn.to_double(),
  )
}

///|
async fn main {
  let mut total_conn = 1000
  let mut max_concurrent_conn = 100
  let mut conn_duration = 500
  let mut addr_str = ""
  loop @env.args()[1:] {
    [] => ()
    ["-total-conn", .. rest] => {
      guard rest is [n, .. rest] else {
        fail("expected total connection number")
      }
      total_conn = @string.parse_int(n)
      continue rest
    }
    ["-max-concurrent", .. rest] => {
      guard rest is [n, .. rest] else {
        fail("expected max concurrent connection count")
      }
      max_concurrent_conn = @string.parse_int(n)
      continue rest
    }
    ["-conn-duration", .. rest] => {
      guard rest is [n, .. rest] else {
        fail("expected duration of connection in milliseconds")
      }
      conn_duration = @string.parse_int(n)
      continue rest
    }
    [opt, ..] if opt.has_prefix("-") => fail("unknown option `\{opt}`")
    [addr, .. rest] => {
      guard addr_str == "" else {
        fail("server addres supplied multiple times")
      }
      addr_str = addr
      continue rest
    }
  }
  guard addr_str != "" else { fail("server address not supplied") }
  let addr = @socket.Addr::parse(addr_str)
  let rand = {
    let seed = @buffer.new()
    let now = @env.now()
    seed
    ..write_uint64_le(now)
    ..write_uint64_le(now)
    ..write_uint64_le(now)
    .write_uint64_le(now)
    @random.Rand::chacha8(seed=seed.contents())
  }
  let (throughput, average_latency) = client(
    rand,
    addr,
    total_conn~,
    max_concurrent_conn~,
    conn_duration~,
  )
  fn show_size(n : Int64) {
    let units = ["b", "kb", "mb", "gb"]
    loop (units[:], n.to_double()) {
      ([], _) => panic()
      ([_, .. rest], n) if n >= 1024 => continue (rest, n / 1024)
      ([unit, ..], n) => "\{n} \{unit}"
    }
  }

  println("average throughput: \{show_size(throughput)}/s")
  println("average latency: \{average_latency} ms")
}
