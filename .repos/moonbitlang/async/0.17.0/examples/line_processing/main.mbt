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
struct Options {
  mut contains : String?
}

///|
async fn print_usage() -> Unit {
  @stdio.stdout.write(
    (
      #|Line-based stream processing example.
      #|
      #|Usage:
      #|  moon -C examples run line_processing -- [OPTIONS] [FILE...]
      #|
      #|Options:
      #|  -c, --contains PATTERN    Only output lines that contain PATTERN
      #|  -h, --help                Show this help text
      #|
      #|Notes:
      #|  - Use "-" to read from stdin.
      #|  - Input is processed incrementally via `read_until("\\n")`.
      #|
    ),
  )
}

///|
fn line_prefix(line_no : Int) -> String {
  let n = if line_no < 10 { "0\{line_no}" } else { "\{line_no}" }
  "L\{n}: "
}

///|
async fn process_lines(
  name : String,
  input : &@io.Reader,
  output : &@io.Writer,
  options : Options,
  show_name~ : Bool,
) -> Unit {
  let mut line_no = 1
  while input.read_until("\n") is Some(line) {
    let keep = match options.contains {
      None => true
      Some(pattern) => line.contains(pattern)
    }
    if keep {
      if show_name {
        output..write(name).write(":")
      }
      output..write(line_prefix(line_no))..write(line).write("\n")
    }
    line_no += 1
  }
}

///|
async fn process_input(
  path : String,
  output : &@io.Writer,
  options : Options,
  show_name~ : Bool,
) -> Unit {
  if path == "-" {
    process_lines("stdin", @stdio.stdin, output, options, show_name~)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    process_lines(path, file, output, options, show_name~)
  }
}

///|
async fn main {
  let options : Options = { contains: None }
  let inputs : Array[String] = []
  loop @env.args()[1:] {
    [] => ()
    ["-h", ..] | ["--help", ..] => {
      print_usage()
      return
    }
    ["-c", .. rest] | ["--contains", .. rest] => {
      guard rest is [pattern, .. rest] else {
        fail("expected PATTERN after --contains")
      }
      options.contains = Some(pattern)
      continue rest
    }
    [opt, ..] if opt.has_prefix("-") && opt != "-" =>
      fail("unknown option `\{opt}`")
    [path, .. rest] => {
      inputs.push(path)
      continue rest
    }
  }
  if inputs.is_empty() {
    inputs.push("-")
  }
  let show_name = inputs.length() > 1
  let out = @io.BufferedWriter::new(@stdio.stdout, size=16 * 1024)
  for path in inputs {
    process_input(path, out, options, show_name~)
  }
  out.flush()
}
