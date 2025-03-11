///|
struct RegExp {
  pattern : String
  prog : Program
}

///|
fn RegExp::new(pattern : String) -> RegExp! {
  let ast = Parser::new(pattern).parse!()
  let prog = Emitter::new(ast).emit()
  { pattern, prog }
}

///|
pub fn compile(pattern : String) -> RegExp! {
  RegExp::new!(pattern)
}

///|
pub fn pattern(self : RegExp) -> String {
  self.pattern
}

///|
pub fn matches(
  self : RegExp,
  text : String,
  start~ : Int = 0,
  end~ : Int = text.length()
) -> MatchResult {
  Interpreter::new(self.prog).scan(text, start, end)
}
