///|
priv enum TraverseStatus {
  BeforeChild
  AfterChild
}

///|
priv struct Emitter {
  ast : Ast
  bytecodes : Array[Int]
  classes : Array[CharClass]
  stack : Array[Int]
}

///|
fn Emitter::new(ast : Ast) -> Emitter {
  { ast, bytecodes: [], classes: [], stack: [] }
}

///|
fn push_stack(self : Emitter, val : Int) -> Unit {
  self.stack.push(val)
}

///|
fn pop_stack(self : Emitter) -> Int {
  self.stack.unsafe_pop()
}

///|
fn cur_pos(self : Emitter) -> Int {
  self.bytecodes.length()
}

///|
fn patch_jump(self : Emitter, offset : Int, dest : Int) -> Unit {
  self.bytecodes[offset + 1] = dest
}

///|
fn emit_0(self : Emitter, op : OpCode) -> Unit {
  self.bytecodes.push(op.to_bytecode())
}

///|
fn emit_1(self : Emitter, op : OpCode, operand : Int) -> Unit {
  self.bytecodes.push(op.to_bytecode())
  self.bytecodes.push(operand)
}

///|
fn emit_2(self : Emitter, op : OpCode, operand1 : Int, operand2 : Int) -> Unit {
  self.bytecodes.push(op.to_bytecode())
  self.bytecodes.push(operand1)
  self.bytecodes.push(operand2)
}

///|
fn emit(self : Emitter) -> Program {
  self.emit_1(BranchLazy, 0)
  let mut cur_node = self.ast.root
  let mut cur_child = 0
  for {
    let cur_child_num = cur_node.child_num()
    if cur_child_num == 0 {
      self.emit_fragment(cur_node, 0)
    } else if cur_child < cur_child_num {
      self.emit_fragment(cur_node, cur_child, status=BeforeChild)
      self.push_stack(cur_child)
      cur_node = cur_node.get_child(cur_child)
      cur_child = 0
      continue
    }
    if self.stack.is_empty() {
      break
    }
    cur_child = self.pop_stack()
    cur_node = cur_node.parent.unwrap()
    self.emit_fragment(cur_node, cur_child, status=AfterChild)
    cur_child += 1
  }
  self.patch_jump(0, self.cur_pos())
  self.emit_0(Stop)
  {
    bytecodes: self.bytecodes,
    classes: self.classes,
    capture_num: self.ast.capture_num,
    capture_name_mapping: self.ast.capture_name_mapping,
  }
}

///|
fn emit_fragment(
  self : Emitter,
  node : AstNode,
  cur_child : Int,
  status~ : TraverseStatus = BeforeChild
) -> Unit {
  match (node.internal, status) {
    (Empty, _) | (Concatenate, _) => ()
    (Alternate, BeforeChild) =>
      if cur_child < node.child_num() - 1 {
        self.push_stack(self.cur_pos())
        self.emit_1(BranchLazy, 0)
      }
    (Alternate, AfterChild) =>
      if cur_child < node.child_num() - 1 {
        let branch_pos = self.pop_stack()
        self.push_stack(self.bytecodes.length())
        self.emit_1(Goto, 0)
        self.patch_jump(branch_pos, self.cur_pos())
      } else {
        for i = 0; i < cur_child; i = i + 1 {
          self.patch_jump(self.pop_stack(), self.cur_pos())
        }
      }
    (Loop(min~, max~, ..), BeforeChild) => {
      if min > 1 || not(max.is_empty()) {
        if min == 0 {
          self.emit_1(NullCount, 0)
        } else {
          self.emit_1(SetCount, 1 - min)
        }
      } else {
        let opcode : OpCode = if min == 0 { NullMark } else { SetMark }
        self.emit_0(opcode)
      }
      if min == 0 {
        self.push_stack(self.cur_pos())
        self.emit_1(Goto, 0)
      }
      self.push_stack(self.cur_pos())
    }
    (Loop(min~, max~, greedy~), AfterChild) => {
      let jump_dest = self.cur_pos()
      if min > 1 || not(max.is_empty()) {
        let opcode : OpCode = if greedy { BranchCount } else { BranchCountLazy }
        let count = if max.is_empty() {
          @int.max_value
        } else {
          max.unwrap() - min
        }
        self.emit_2(opcode, self.pop_stack(), count)
      } else {
        let opcode : OpCode = if greedy { BranchMark } else { BranchMarkLazy }
        self.emit_1(opcode, self.pop_stack())
      }
      if min == 0 {
        self.patch_jump(self.pop_stack(), jump_dest)
      }
    }
    (Capture(_), BeforeChild) => self.emit_0(SetMark)
    (Capture(index~), AfterChild) => self.emit_1(CaptureMark, index)
    (Group, _) => ()
    (Single(char~), _) => self.emit_1(Single, char.to_int())
    (NotSingle(char~), _) => self.emit_1(NotSingle, char.to_int())
    (Class(class~), _) => {
      let idx = self.classes.length()
      self.classes.push(class)
      self.emit_1(Class, idx)
    }
    (SingleLoop(char~, min~, max~, greedy~), _) => {
      let opd = char.to_int()
      if min > 0 {
        self.emit_2(SingleRepeat, opd, min)
      }
      let opcode : OpCode = if greedy { SingleLoop } else { SingleLazy }
      match max {
        Some(max) => if max != min { self.emit_2(opcode, opd, max - min) }
        None => self.emit_2(opcode, opd, @int.max_value)
      }
    }
    (NotSingleLoop(char~, min~, max~, greedy~), _) => {
      let opd = char.to_int()
      if min > 0 {
        self.emit_2(NotSingleRepeat, opd, min)
      }
      let opcode : OpCode = if greedy { NotSingleLoop } else { NotSingleLazy }
      match max {
        Some(max) => if max != min { self.emit_2(opcode, opd, max - min) }
        None => self.emit_2(opcode, opd, @int.max_value)
      }
    }
    (ClassLoop(class~, min~, max~, greedy~), _) => {
      let idx = self.classes.length()
      self.classes.push(class)
      if min > 0 {
        self.emit_2(ClassRepeat, idx, min)
      }
      let opcode : OpCode = if greedy { ClassLoop } else { ClassLazy }
      match max {
        Some(max) => if max != min { self.emit_2(opcode, idx, max - min) }
        None => self.emit_2(opcode, idx, @int.max_value)
      }
    }
    (BeginOfInput, _) => self.emit_0(BeginOfInput)
    (EndOfInput, _) => self.emit_0(EndOfInput)
  }
}
