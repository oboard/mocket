///|
let max_loop_count = 100_000

///|
pub(all) type! ParseError {
  InternalParserError
  UnmatchedGroupBegin(pos~ : Int)
  UnmatchedGroupEnd(pos~ : Int)
  UnmatchedGroupName(pos~ : Int)
  EmptyGroupName(pos~ : Int)
  EmptyGroup(pos~ : Int)
  UnmatchedCharClassEnd(pos~ : Int)
  UnspecifiedLoopTarget(pos~ : Int)
  InvalidLoop(pos~ : Int)
  LoopCountOutOfRange(pos~ : Int)
  LoopMaxCountSmallerThanMinCount(pos~ : Int)
  EndPatternAtEscape(pos~ : Int)
  ClassMissingBracket(pos~ : Int)
  GroupMissingParen(pos~ : Int)
} derive(Eq, Show)

///|
priv struct Parser {
  pattern : String
  mut pos : Int
  mut pos_mark : Int
  mut group_index : Int
  mut capture_num : Int
  capture_name_mapping : Map[String, Int]
}

///|
fn Parser::new(pattern : String) -> Parser {
  {
    pattern,
    pos: 0,
    pos_mark: 0,
    group_index: 0,
    capture_num: 0,
    capture_name_mapping: {},
  }
}

///|
fn pos(self : Parser) -> Int {
  self.pos
}

///|
fn Parser::rewind(self : Parser, n : Int) -> Unit {
  self.pos -= n
}

///|
fn Parser::advance(self : Parser, n : Int) -> Unit {
  self.pos += n
}

///|
fn mark(self : Parser) -> Unit {
  self.pos_mark = self.pos
}

///|
fn restore(self : Parser) -> Unit {
  self.pos = self.pos_mark
}

///|
fn more(self : Parser) -> Bool {
  self.pos < self.pattern.length()
}

///|
fn peek(self : Parser) -> Char {
  if not(self.more()) {
    abort("index out of bounds")
  }
  self.pattern[self.pos]
}

///|
fn peek_is(self : Parser, expected : Char) -> Bool {
  if not(self.more()) {
    false
  } else {
    self.peek() == expected
  }
}

///|
fn check_exist(self : Parser, c : Char) -> Bool {
  self.mark()
  while self.more() {
    if self.peek_is(c) {
      self.restore()
      return true
    }
    self.advance(1)
  }
  self.restore()
  false
}

///|
fn fetch_unsigned_num(self : Parser) -> Int? {
  let num_buf = @buffer.new()
  loop self.peek() {
    '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' as d => {
      num_buf.write_char(d)
      self.advance(1)
      if self.more() {
        continue self.peek()
      }
    }
    _ => break
  }
  let num_str = num_buf.contents().to_unchecked_string()
  if num_str == "" {
    return None
  }
  try {
    let num = @strconv.parse_int!(num_str)
    Some(num)
  } catch {
    _ => None
  }
}

///|
fn parse(self : Parser) -> Ast!ParseError {
  let root = AstNode::new(Capture(index=self.group_index))
  self.group_index += 1
  self.capture_num += 1
  root.add_child(self.parse_expr!(false))
  {
    root,
    capture_num: self.capture_num,
    capture_name_mapping: self.capture_name_mapping,
  }
}

///|
fn parse_expr(self : Parser, in_group : Bool) -> AstNode!ParseError {
  let node = self.parse_concat!(in_group)
  if not(self.more()) || (in_group && self.peek_is(')')) {
    return node
  } else if self.peek_is('|') {
    let alt_node = AstNode::new(Alternate)
    alt_node.add_child(node)
    while self.peek_is('|') {
      self.advance(1) // |
      alt_node.add_child(self.parse_concat!(in_group))
    }
    if not(in_group) && self.more() {
      raise InternalParserError
    } else {
      alt_node
    }
  } else {
    raise InternalParserError
  }
}

///|
fn parse_concat(self : Parser, in_group : Bool) -> AstNode!ParseError {
  let node = self.parse_node!(in_group)
  if not(self.more()) || self.peek_is('|') || (in_group && self.peek_is(')')) {
    node
  } else {
    let concat_node = AstNode::new(Concatenate)
    concat_node.add_child(node)
    while self.more() &&
          not(self.peek_is('|')) &&
          not(in_group && self.peek_is(')')) {
      concat_node.add_child(self.parse_node!(in_group))
    }
    concat_node
  }
}

///|
fn parse_node(self : Parser, in_group : Bool) -> AstNode!ParseError {
  if not(self.more()) || (in_group && self.peek_is(')')) {
    return AstNode::new(Empty)
  }
  let node = match self.peek() {
    '|' => {
      self.advance(1)
      AstNode::new(Empty)
    }
    '.' => {
      self.advance(1)
      AstNode::new(NotSingle(char='\n'))
    }
    '^' => {
      self.advance(1)
      AstNode::new(BeginOfInput)
    }
    '$' => {
      self.advance(1)
      AstNode::new(EndOfInput)
    }
    '(' => {
      self.advance(1)
      self.parse_group!()
    }
    ')' => raise UnmatchedGroupEnd(pos=self.pos)
    '[' => {
      self.advance(1)
      self.parse_class!()
    }
    ']' => raise UnmatchedCharClassEnd(pos=self.pos)
    '*' | '+' | '?' | '{' | '}' => raise UnspecifiedLoopTarget(pos=self.pos)
    '\\' => {
      self.advance(1)
      self.parse_escape!()
    }
    _ as char => {
      self.advance(1)
      AstNode::new(Single(char~))
    }
  }
  self.parse_loop!(node)
}

///|
fn parse_loop(self : Parser, target : AstNode) -> AstNode!ParseError {
  if not(self.more()) {
    return target
  }
  let mut greedy = true
  let mut min = 0
  let mut max : Int? = None
  match self.peek() {
    '*' => self.advance(1)
    '+' => {
      self.advance(1)
      min = 1
    }
    '?' => {
      self.advance(1)
      max = Some(1)
    }
    '{' => {
      self.advance(1)
      let range = self.parse_loop_range!()
      min = range.0
      max = range.1
    }
    _ => return target
  }
  if self.peek_is('?') {
    self.advance(1)
    greedy = false
  }
  match target.internal {
    Single(char~) => AstNode::new(SingleLoop(char~, min~, max~, greedy~))
    NotSingle(char~) => AstNode::new(NotSingleLoop(char~, min~, max~, greedy~))
    Class(class~) => AstNode::new(ClassLoop(class~, min~, max~, greedy~))
    _ => {
      let node = AstNode::new(Loop(min~, max~, greedy~))
      node.add_child(target)
      node
    }
  }
}

///|
fn parse_loop_range(self : Parser) -> (Int, Int?)!ParseError {
  if not(self.more()) {
    raise InvalidLoop(pos=self.pos)
  }
  let min = match self.fetch_unsigned_num() {
    Some(v) => v
    None => raise InvalidLoop(pos=self.pos)
  }
  if min < 0 || min > max_loop_count {
    raise LoopCountOutOfRange(pos=self.pos)
  }
  if not(self.more()) {
    raise InvalidLoop(pos=self.pos)
  }
  let max : Int? = if self.peek_is(',') {
    self.advance(1) // ','
    self.fetch_unsigned_num()
  } else {
    Some(min)
  }
  if not(max.is_empty()) && (max.unwrap() < 0 || max.unwrap() > max_loop_count) {
    raise LoopCountOutOfRange(pos=self.pos)
  }
  if not(self.more()) || not(self.peek_is('}')) {
    raise InvalidLoop(pos=self.pos)
  }
  self.advance(1) // '}'
  if not(max.is_empty()) && min > max.unwrap() {
    raise LoopMaxCountSmallerThanMinCount(pos=self.pos)
  }
  (min, max)
}

///|
fn parse_group(self : Parser) -> AstNode!ParseError {
  if not(self.more()) {
    raise UnmatchedGroupBegin(pos=self.pos)
  }
  let mut capture = true
  let mut name = ""
  let index = self.group_index
  self.group_index += 1
  self.capture_num += 1
  if self.peek_is('?') {
    self.advance(1) // '?'
    match self.peek() {
      ':' => {
        capture = false
        self.capture_num -= 1
        self.advance(1) // ':'
      }
      '<' => {
        name = self.parse_group_name!()
        if name == "" {
          raise EmptyGroupName(pos=self.pos)
        }
        self.capture_name_mapping.set(name, index)
      }
      _ => ()
    }
  }
  if not(self.more()) || self.peek_is(')') {
    raise EmptyGroup(pos=self.pos)
  }
  let node = if capture {
    AstNode::new(Capture(index~))
  } else {
    AstNode::new(Group)
  }
  node.add_child(self.parse_expr!(true))
  if not(self.more()) || not(self.peek_is(')')) {
    raise GroupMissingParen(pos=self.pos)
  }
  self.advance(1) // ')'
  node
}

///|
fn parse_group_name(self : Parser) -> String!ParseError {
  self.advance(1) // '<'
  let buf = @buffer.new()
  while self.more() && not(self.peek_is('>')) {
    buf.write_char(self.peek())
    self.advance(1)
  }
  if not(self.peek_is('>')) {
    raise UnmatchedGroupName(pos=self.pos)
  }
  self.advance(1) // '>'
  buf.contents().to_unchecked_string()
}

///|
fn parse_class(self : Parser) -> AstNode!ParseError {
  let neg = if self.peek_is('^') {
    self.advance(1)
    true
  } else {
    false
  }
  let mut first = true
  let char_class = CharClass::new(neg~)
  // Allow ']' and '-' as first char in class
  while self.more() && (not(self.peek_is(']')) || first) {
    if (self.peek_is(']') || self.peek_is('-')) && first {
      char_class.add_single(self.peek())
      self.advance(1)
    }
    first = false
    if self.peek_is('\\') {
      self.advance(1)
      match self.peek() {
        'd' => char_class.add_category(Digit)
        'D' => char_class.add_category(NotDigit)
        's' => char_class.add_category(Space)
        'S' => char_class.add_category(NotSpace)
        'w' => char_class.add_category(Word)
        'W' => char_class.add_category(NotWord)
        't' => char_class.add_single('\t')
        'r' => char_class.add_single('\r')
        'n' => char_class.add_single('\n')
        'v' => char_class.add_single('\u000B')
        'f' => char_class.add_single('\u000C')
        _ as c => char_class.add_single(c)
      }
      self.advance(1)
    } else {
      let low = self.parse_char_class_char!()
      let mut high = low
      if self.more() && self.peek_is('-') {
        self.advance(1) // '-'
        if self.more() && self.peek_is(']') {
          // '-' is the last char
          self.rewind(1)
        } else {
          high = self.parse_char_class_char!()
        }
      }
      char_class.add_range(low, high)
    }
  }
  if not(self.more()) || not(self.peek_is(']')) {
    raise ClassMissingBracket(pos=self.pos)
  } else {
    self.advance(1) // ']'
    AstNode::new(Class(class=char_class))
  }
}

///|
fn parse_char_class_char(self : Parser) -> Char!ParseError {
  if not(self.more()) {
    raise ClassMissingBracket(pos=self.pos)
  }
  if self.peek_is('\\') {
    self.advance(1)
  }
  let c = self.peek()
  self.advance(1)
  c
}

///|
fn parse_escape(self : Parser) -> AstNode!ParseError {
  if not(self.more()) {
    raise EndPatternAtEscape(pos=self.pos)
  }
  let node : AstNodeInternal = match self.peek() {
    'd' => Class(class=CharClass::new()..add_category(Digit))
    'D' => Class(class=CharClass::new()..add_category(NotDigit))
    's' => Class(class=CharClass::new()..add_category(Space))
    'S' => Class(class=CharClass::new()..add_category(NotSpace))
    'w' => Class(class=CharClass::new()..add_category(Word))
    'W' => Class(class=CharClass::new()..add_category(NotWord))
    't' => Single(char='\t')
    'r' => Single(char='\r')
    'n' => Single(char='\n')
    'v' => Single(char='\u000B')
    'f' => Single(char='\u000C')
    _ as char => Single(char~)
  }
  self.advance(1)
  AstNode::new(node)
}
