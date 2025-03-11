///|
priv enum AstNodeInternal {
  // Leave nodes of the AST.
  Empty
  Single(char~ : Char)
  NotSingle(char~ : Char)
  Class(class~ : CharClass)
  // Multi(~str : String)
  SingleLoop(char~ : Char, min~ : Int, max~ : Int?, greedy~ : Bool)
  NotSingleLoop(char~ : Char, min~ : Int, max~ : Int?, greedy~ : Bool)
  ClassLoop(class~ : CharClass, min~ : Int, max~ : Int?, greedy~ : Bool)
  // Backreference(~index : Int)
  BeginOfInput
  EndOfInput
  // Branch nodes of the AST that have at least one child.
  Alternate
  Concatenate
  Loop(min~ : Int, max~ : Int?, greedy~ : Bool)
  Capture(index~ : Int)
  Group
} derive(Eq)

///|
fn to_string(self : AstNodeInternal) -> String {
  fn range_str(min : Int, max : Int?) {
    match max {
      Some(max) => if min == max { "{\{min}} " } else { "{\{min},\{max}} " }
      None => "{\{min},} "
    }
  }

  fn greedy_str(g : Bool) -> String {
    if g {
      "Greedy "
    } else {
      "NonGreedy "
    }
  }

  match self {
    Empty => "Empty"
    Single(char~) => "Single " + char.to_int().to_string()
    NotSingle(char~) => "NotSingle " + char.to_int().to_string()
    Class(class~) => "Class " + class.to_string()
    SingleLoop(char~, min~, max~, greedy~) =>
      "SingleLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      char.to_int().to_string()
    NotSingleLoop(char~, min~, max~, greedy~) =>
      "NotSingleLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      char.to_int().to_string()
    ClassLoop(class~, min~, max~, greedy~) =>
      "ClassLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      class.to_string()
    BeginOfInput => "BeginOfLine"
    EndOfInput => "EndOfLine"
    Alternate => "Alternate"
    Concatenate => "Concatenate"
    Loop(min~, max~, greedy~) =>
      "Loop " + greedy_str(greedy) + range_str(min, max)
    Capture(index~) => "Capture \{index}"
    Group => "Group"
  }
}

///|
priv struct AstNode {
  internal : AstNodeInternal
  mut parent : AstNode?
  children : Array[AstNode]
}

///|
fn AstNode::new(
  internal : AstNodeInternal,
  parent~ : AstNode? = None,
  children~ : Array[AstNode] = []
) -> AstNode {
  { internal, parent, children }
}

///|
fn add_child(self : AstNode, child : AstNode) -> Unit {
  child.parent = Some(self)
  self.children.push(child)
}

///|
fn get_child(self : AstNode, idx : Int) -> AstNode {
  self.children[idx]
}

///|
fn child_num(self : AstNode) -> Int {
  self.children.length()
}

///|
impl Show for AstNode with output(self, logger) -> Unit {
  let mut cur_node = self
  let mut cur_child = 0
  let stack = []
  logger.write_string(cur_node.internal.to_string())
  logger.write_char('\n')
  for {
    if cur_child < cur_node.child_num() {
      stack.push(cur_child + 1)
      cur_node = cur_node.get_child(cur_child)
      cur_child = 0
      for i = 0; i < stack.length(); i = i + 1 {
        logger.write_string("  ")
      }
      logger.write_string(cur_node.internal.to_string())
      logger.write_char('\n')
    } else {
      if stack.is_empty() {
        break
      }
      cur_child = stack.unsafe_pop()
      cur_node = match cur_node.parent {
        Some(node) => node
        None => break
      }
    }
  }
}

///|
priv struct Ast {
  root : AstNode
  capture_num : Int
  capture_name_mapping : Map[String, Int]
}

///|
impl Show for Ast with output(self, logger) {
  logger.write_char('\n')
  logger.write_string("Number of captures: " + self.capture_num.to_string())
  logger.write_char('\n')
  logger.write_string("Capture name mapping: ")
  logger.write_string(self.capture_name_mapping.to_string())
  logger.write_char('\n')
  logger.write_string("Ast:\n")
  logger.write_string(self.root.to_string())
}
