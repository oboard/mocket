///|
priv enum RunningStatus {
  Normal
  Backtracking
  BacktrackingBranch
} derive(Show, Eq)

///|
priv struct Interpreter {
  prog : Program
  mut status : RunningStatus
  mut op_code : OpCode
  mut op_pos : Int
  mut text_start : Int
  mut text_end : Int
  mut text_pos : Int
  op_stack : Array[Int]
  track_stack : Array[Int]
  run_stack : Array[Int]
  capture_stack : Array[Int]
  captures : Array[(Int, Int)?]
}

///|
fn Interpreter::new(prog : Program) -> Interpreter {
  {
    prog,
    status: Normal,
    op_code: Nop,
    op_pos: 0,
    text_start: 0,
    text_end: 0,
    text_pos: 0,
    op_stack: [],
    track_stack: [],
    run_stack: [],
    capture_stack: [],
    captures: Array::makei(prog.capture_num, fn(_i) { None }),
  }
}

///|
fn advance(self : Interpreter, num : Int) -> Unit {
  self.op_pos += num
  self.op_code = self.prog.op_code(self.op_pos)
}

///|
fn goto(self : Interpreter, pos : Int) -> Unit {
  self.op_pos = pos
  self.op_code = self.prog.op_code(self.op_pos)
}

///|
fn operand(self : Interpreter, n : Int) -> Int {
  self.prog.operand(self.op_pos + n + 1)
}

///|
fn backtrack(self : Interpreter) -> Unit {
  let op_pos = self.op_pop()
  if op_pos < 0 {
    self.status = BacktrackingBranch
    self.op_pos = -op_pos
  } else {
    self.status = Backtracking
    self.op_pos = op_pos
  }
  self.op_code = self.prog.op_code(self.op_pos)
}

///|
fn capture(self : Interpreter, idx : Int, start : Int, end : Int) -> Unit {
  let (start, end) = if end < start { (end, start) } else { (start, end) }
  self.capture_stack.push(idx)
  self.captures[idx] = Some((start, end))
}

///|
fn uncapture(self : Interpreter) -> Unit {
  let idx = self.capture_stack.unsafe_pop()
  self.captures[idx] = None
}

///|
fn op_push(self : Interpreter, branch~ : Bool = false) -> Unit {
  self.op_stack.push(if branch { -self.op_pos } else { self.op_pos })
}

///|
fn op_pop(self : Interpreter) -> Int {
  self.op_stack.unsafe_pop()
}

///|
fn track_push(self : Interpreter, arg : Int) -> Unit {
  self.track_stack.push(arg)
}

///|
fn track_pop(self : Interpreter) -> Int {
  self.track_stack.unsafe_pop()
}

///|
fn run_push(self : Interpreter, arg : Int) -> Unit {
  self.run_stack.push(arg)
}

///|
fn run_pop(self : Interpreter) -> Int {
  self.run_stack.unsafe_pop()
}

///|
fn chars_remain(self : Interpreter) -> Int {
  self.text_end - self.text_pos
}

///|
fn next_char(self : Interpreter, text : String) -> Int {
  self.text_pos += 1
  text[self.text_pos - 1].to_int()
}

///|
fn rewind(self : Interpreter) -> Unit {
  self.text_pos -= 1
}

///|
fn char_in_class(self : Interpreter, class_idx : Int, char : Int) -> Bool {
  let class = self.prog.classes[class_idx]
  class.contains(char)
}

///|
fn scan(
  self : Interpreter,
  text : String,
  start : Int,
  end : Int
) -> MatchResult {
  self.text_start = start
  self.text_end = end
  self.text_pos = self.text_start
  while self.text_pos <= text.length() {
    if self.try_match(text) {
      break
    }
    self.text_pos += 1
  }
  let captures = self.captures.map(fn(r) {
    if r == None {
      ""
    } else {
      let (start, end) = r.unwrap()
      text.substring(start~, end~)
    }
  })
  let named_captures = {}
  for k, v in self.prog.capture_name_mapping {
    named_captures[k] = captures[v]
  }
  { success: self.captures[0] != None, captures, named_captures }
}

///|
fn try_match(self : Interpreter, text : String) -> Bool {
  self.op_pos = 0
  self.op_code = self.prog.op_code(self.op_pos)
  for {
    let cur_opcode = self.op_code
    let cur_status = self.status
    if self.status == Backtracking {
      self.status = Normal
    }
    match (cur_opcode, cur_status) {
      (Nop, _) => {
        self.advance(1)
        continue
      }
      (Stop, _) => return self.captures[0] != None
      (Goto, _) => {
        self.goto(self.operand(0))
        continue
      }
      (BeginOfInput, _) =>
        if self.text_pos == self.text_start {
          self.advance(1)
          continue
        }
      (EndOfInput, _) =>
        if self.text_pos >= self.text_end {
          self.advance(1)
          continue
        }
      (BranchLazy, Normal) => {
        self.op_push()
        self.track_push(self.text_pos)
        self.advance(2)
        continue
      }
      (BranchLazy, Backtracking) => {
        self.text_pos = self.track_pop()
        self.goto(self.operand(0))
        continue
      }
      (SetMark, Normal) => {
        self.op_push()
        self.run_push(self.text_pos)
        self.advance(1)
        continue
      }
      (SetMark, Backtracking) => {
        let _ = self.run_pop()

      }
      (NullMark, Normal) => {
        self.op_push()
        self.run_push(-1)
        self.advance(1)
        continue
      }
      (NullMark, Backtracking) => {
        let _ = self.run_pop()

      }
      (GetMark, Normal) => {
        self.op_push()
        let text_pos = self.run_pop()
        self.track_push(text_pos)
        self.text_pos = text_pos
        self.advance(1)
        continue
      }
      (GetMark, Backtracking) => self.run_push(self.track_pop())
      (CaptureMark, Normal) => {
        self.op_push()
        let mark = self.run_pop()
        self.capture(self.operand(0), mark, self.text_pos)
        self.track_push(mark)
        self.advance(2)
        continue
      }
      (CaptureMark, Backtracking) => {
        self.run_push(self.track_pop()) // mark
        self.uncapture()
      }
      (BranchMark, Normal) => {
        let mark = self.run_pop()
        if self.text_pos != mark {
          // Non-empty match, go loop.
          self.op_push()
          // Save old mark and text_pos
          self.track_push(self.text_pos)
          self.track_push(mark)
          // Make new mark
          self.run_push(self.text_pos)
          self.goto(self.operand(0))
        } else {
          // Empty match, go straight.
          self.op_push(branch=true)
          // Save old mark
          self.track_push(mark)
          self.advance(2)
        }
        continue
      }
      (BranchMark, Backtracking) => {
        let _mark = self.run_pop()
        let old_mark = self.track_pop()
        let text_pos = self.track_pop()
        // Restore text_pos
        self.text_pos = text_pos
        // Save old mark and go straight
        self.op_push(branch=true)
        self.track_push(old_mark)
        self.advance(2)
        continue
      }
      (BranchMark, BacktrackingBranch) => {
        // Restore old mark and backtrack
        let old_mark = self.track_pop()
        self.run_push(old_mark)
      }
      (SetCount, Normal) => {
        self.op_push()
        self.run_push(self.operand(0)) // count
        self.run_push(self.text_pos) // mark
        self.advance(2)
        continue
      }
      (SetCount, Backtracking) => {
        let _ = self.run_pop()
        let _ = self.run_pop()

      }
      (NullCount, Normal) => {
        self.op_push()
        self.run_push(self.operand(0)) // count
        self.run_push(-1) // mark
        self.advance(2)
        continue
      }
      (NullCount, Backtracking) => {
        let _ = self.run_pop()
        let _ = self.run_pop()

      }
      (BranchCount, Normal) => {
        let mark = self.run_pop()
        let count = self.run_pop()
        let matched = self.text_pos - mark
        if count >= self.operand(1) || (matched == 0 && count >= 0) {
          // Max loops or empty match, go straight
          self.op_push(branch=true)
          self.track_push(count)
          self.track_push(mark)
          self.advance(3)
        } else {
          // Non-empty match, increase count and go loop
          self.op_push()
          self.track_push(mark)
          self.run_push(count + 1)
          self.run_push(self.text_pos)
          self.goto(self.operand(0))
        }
        continue
      }
      (BranchCount, Backtracking) => {
        let old_mark = self.track_pop()
        let text_pos = self.run_pop()
        let count = self.run_pop()
        if count > 0 {
          self.text_pos = text_pos
          // Save old mark and old count
          self.op_push(branch=true)
          self.track_push(count - 1)
          self.track_push(old_mark)
          // Go straight
          self.advance(3)
          continue
        }
        // Restore old mark and old count
        self.run_push(count - 1)
        self.run_push(old_mark)
      }
      (BranchCount, BacktrackingBranch) => {
        let mark = self.track_pop()
        let count = self.track_pop()
        self.run_push(count)
        self.run_push(mark)
      }
      (BranchCountLazy, Normal) => {
        let mark = self.run_pop()
        let count = self.run_pop()
        if count < 0 {
          // Go loop
          self.op_push(branch=true)
          // Save old mark
          self.track_push(mark)
          // Make new mark and increase count
          self.run_push(count + 1)
          self.run_push(self.text_pos)
          self.goto(self.operand(0))
        } else {
          // Go straight
          self.op_push()
          // Save mark, count, text_pos
          self.track_push(self.text_pos)
          self.track_push(count)
          self.track_push(mark)
          self.advance(3)
        }
        continue
      }
      (BranchCountLazy, Backtracking) => {
        let mark = self.track_pop()
        let count = self.track_pop()
        let text_pos = self.track_pop()
        if count < self.operand(1) && text_pos != mark {
          // Not reach the limit and not empty match
          self.op_push()
          // Restore text position
          self.text_pos = text_pos
          // Save old mark
          self.track_push(mark)
          // Make new mark and increase count
          self.run_push(count + 1)
          self.run_push(text_pos)
          // Loop
          self.goto(self.operand(0))
          continue
        } else {
          // Backtrack
          self.run_push(count)
          self.run_push(mark)
        }
      }
      (BranchCountLazy, BacktrackingBranch) => {
        let old_mark = self.track_pop()
        let _mark = self.run_pop()
        let count = self.run_pop()
        // Restore old mark and count
        self.run_push(count - 1)
        self.run_push(old_mark)
      }
      (Single, _) =>
        if self.chars_remain() >= 1 && self.next_char(text) == self.operand(0) {
          self.advance(2)
          continue
        }
      (NotSingle, _) =>
        if self.chars_remain() >= 1 && self.next_char(text) != self.operand(0) {
          self.advance(2)
          continue
        }
      (Class, _) =>
        if self.chars_remain() >= 1 &&
          self.char_in_class(self.operand(0), self.next_char(text)) {
          self.advance(2)
          continue
        }
      (SingleRepeat, _) => {
        let mut matched = false
        let count = self.operand(1)
        if self.chars_remain() >= count {
          let ch = self.operand(0)
          for i = 0; i < count; i = i + 1 {
            if self.next_char(text) != ch {
              break
            }
          } else {
            matched = true
          }
        }
        if matched {
          self.advance(3)
          continue
        }
      }
      (NotSingleRepeat, _) => {
        let mut matched = false
        let count = self.operand(1)
        if self.chars_remain() >= count {
          let ch = self.operand(0)
          for i = 0; i < count; i = i + 1 {
            if self.next_char(text) == ch {
              break
            }
          } else {
            matched = true
          }
        }
        if matched {
          self.advance(3)
          continue
        }
      }
      (ClassRepeat, _) => {
        let mut matched = true
        let class_idx = self.operand(0)
        let count = self.operand(1)
        if self.chars_remain() < count {
          matched = false
        } else {
          for i = 0; i < count; i = i + 1 {
            if not(self.char_in_class(class_idx, self.next_char(text))) {
              matched = false
              self.rewind()
              break
            }
          }
        }
        if matched {
          self.advance(3)
          continue
        }
      }
      (SingleLoop, Normal) => {
        let ch = self.operand(0)
        let max_count = self.operand(1)
        let count = @math.minimum(max_count, self.chars_remain())
        let mut i = count
        while i > 0 {
          if self.next_char(text) != ch {
            self.rewind()
            break
          }
          i -= 1
        }
        if i < count {
          self.op_push()
          self.track_push(count - i - 1)
          self.track_push(self.text_pos - 1)
        }
        self.advance(3)
        continue
      }
      (NotSingleLoop, Normal) => {
        let ch = self.operand(0)
        let max_count = self.operand(1)
        let count = @math.minimum(max_count, self.chars_remain())
        let mut i = count
        while i > 0 {
          if self.next_char(text) == ch {
            self.rewind()
            break
          }
          i -= 1
        }
        if i < count {
          self.op_push()
          self.track_push(count - i - 1)
          self.track_push(self.text_pos - 1)
        }
        self.advance(3)
        continue
      }
      (ClassLoop, Normal) => {
        let max_count = self.operand(1)
        let count = @math.minimum(max_count, self.chars_remain())
        let mut i = count
        while i > 0 {
          if not(self.char_in_class(self.operand(0), self.next_char(text))) {
            self.rewind()
            break
          }
          i -= 1
        }
        if i < count {
          self.op_push()
          self.track_push(count - i - 1)
          self.track_push(self.text_pos - 1)
        }
        self.advance(3)
        continue
      }
      (SingleLoop, Backtracking)
      | (NotSingleLoop, Backtracking)
      | (ClassLoop, Backtracking) => {
        let text_pos = self.track_pop()
        let i = self.track_pop()
        self.text_pos = text_pos
        if i > 0 {
          self.op_push()
          self.track_push(i - 1)
          self.track_push(text_pos - 1)
        }
        self.advance(3)
        continue
      }
      (SingleLazy, Normal) | (NotSingleLazy, Normal) | (ClassLazy, Normal) => {
        let max_count = self.operand(1)
        let count = @math.minimum(max_count, self.chars_remain())
        if count > 0 {
          self.op_push()
          self.track_push(count - 1)
          self.track_push(self.text_pos)
        }
        self.advance(3)
        continue
      }
      (SingleLazy, Backtracking) => {
        let text_pos = self.track_pop()
        self.text_pos = text_pos
        let count = self.track_pop()
        if self.next_char(text) == self.operand(0) {
          if count > 0 {
            self.op_push()
            self.track_push(count - 1)
            self.track_push(text_pos + 1)
          }
          self.advance(3)
          continue
        }
      }
      (NotSingleLazy, Backtracking) => {
        let text_pos = self.track_pop()
        self.text_pos = text_pos
        let count = self.track_pop()
        if self.next_char(text) != self.operand(0) {
          if count > 0 {
            self.op_push()
            self.track_push(count - 1)
            self.track_push(text_pos + 1)
          }
          self.advance(3)
          continue
        }
      }
      (ClassLazy, Backtracking) => {
        let text_pos = self.track_pop()
        self.text_pos = text_pos
        let count = self.track_pop()
        let class = self.prog.classes[self.operand(0)]
        if class.contains(self.next_char(text)) {
          if count > 0 {
            self.op_push()
            self.track_push(count - 1)
            self.track_push(text_pos + 1)
          }
          self.advance(3)
          continue
        }
      }
      (_, _) => panic()
    }
    self.backtrack()
  }
  false
}

///|
fn debug_state(self : Interpreter) -> String {
  let buf = @buffer.new()
  let _ = self.prog.output_op(self.op_pos, buf)
  buf.write_char('\n')
  buf.write_string("text_pos: " + self.text_pos.to_string() + "\n")
  buf.write_string("op_stack: " + self.op_stack.to_string() + "\n")
  buf.write_string("track_stack: " + self.track_stack.to_string() + "\n")
  buf.write_string("run_stack: " + self.run_stack.to_string() + "\n")
  buf.contents().to_unchecked_string()
}
