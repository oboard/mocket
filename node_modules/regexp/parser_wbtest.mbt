///|
fn test_parse(s : String) -> Ast!ParseError {
  Parser::new(s).parse!()
}

// #region single
test "should parse single char" {
  inspect!(
    test_parse!("a"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 97
      #|
    ,
  )
}

test "should parse any char" {
  inspect!(
    test_parse!("."),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  NotSingle 10
      #|
    ,
  )
}

test "should parse escape" {
  inspect!(
    test_parse!("\\s"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\s]
      #|
    ,
  )
  inspect!(
    test_parse!("\\S"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\S]
      #|
    ,
  )
  inspect!(
    test_parse!("\\d"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\d]
      #|
    ,
  )
  inspect!(
    test_parse!("\\D"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\D]
      #|
    ,
  )
  inspect!(
    test_parse!("\\w"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\w]
      #|
    ,
  )
  inspect!(
    test_parse!("\\W"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [\W]
      #|
    ,
  )
  inspect!(
    test_parse!("\\n"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 10
      #|
    ,
  )
  inspect!(
    test_parse!("\\r"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 13
      #|
    ,
  )
  inspect!(
    test_parse!("\\f"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 12
      #|
    ,
  )
  inspect!(
    test_parse!("\\v"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 11
      #|
    ,
  )
  inspect!(
    test_parse!("\\t"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 9
      #|
    ,
  )
  inspect!(
    test_parse!("\\*"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 42
      #|
    ,
  )
}

// #endregion

// #region concat
test "should parse concat" {
  inspect!(
    test_parse!("abc"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Concatenate
      #|    Single 97
      #|    Single 98
      #|    Single 99
      #|
    ,
  )
}
// #endregion

// #region alt
test "should parse alt" {
  inspect!(
    test_parse!("a|b|c"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Alternate
      #|    Single 97
      #|    Single 98
      #|    Single 99
      #|
    ,
  )
}
// #endregion

// #region repeat
test "should parse star" {
  inspect!(
    test_parse!("a*"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {0,} 97
      #|
    ,
  )
}

test "should parse plus" {
  inspect!(
    test_parse!("a+"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {1,} 97
      #|
    ,
  )
}

test "should parse quest" {
  inspect!(
    test_parse!("a?"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {0,1} 97
      #|
    ,
  )
}

test "should parse exact loop" {
  inspect!(
    test_parse!("a{2}"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {2} 97
      #|
    ,
  )
}

test "should parse loop [min, max]" {
  inspect!(
    test_parse!("a{1,2}"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {1,2} 97
      #|
    ,
  )
}

test "should parse loop [min, infinity]" {
  inspect!(
    test_parse!("a{0,}"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop Greedy {0,} 97
      #|
    ,
  )
}

test "should parse non-greedy" {
  inspect!(
    test_parse!("a*?"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop NonGreedy {0,} 97
      #|
    ,
  )
  inspect!(
    test_parse!("a+?"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop NonGreedy {1,} 97
      #|
    ,
  )
  inspect!(
    test_parse!("a??"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop NonGreedy {0,1} 97
      #|
    ,
  )
  inspect!(
    test_parse!("a{0,2}?"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  SingleLoop NonGreedy {0,2} 97
      #|
    ,
  )
}

test "throws on invalid loop" {
  inspect!(test_parse?("a{,1}"), content="Err(InvalidLoop(pos=2))")
  inspect!(test_parse?("a{0,1"), content="Err(InvalidLoop(pos=5))")
  inspect!(test_parse?("a{}"), content="Err(InvalidLoop(pos=2))")
}
// #endregion

// #region class
test "should parse class" {
  inspect!(
    test_parse!("[abc]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [97,98,99]
      #|
    ,
  )
}

test "should parse range class" {
  inspect!(
    test_parse!("[a-z]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [97-122]
      #|
    ,
  )
  inspect!(
    test_parse!("[a-zA-Z]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [97-122,65-90]
      #|
    ,
  )
  inspect!(
    test_parse!("[0-9]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [48-57]
      #|
    ,
  )
}

test "should parse negated class" {
  inspect!(
    test_parse!("[^abc]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [^97,98,99]
      #|
    ,
  )
}

test "should parse escape class" {
  inspect!(
    test_parse!("[A-Za-z\\s]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [65-90,97-122\s]
      #|
    ,
  )
  inspect!(
    test_parse!("[\\D1-3]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [49-51\D]
      #|
    ,
  )
  inspect!(
    test_parse!("[\\f\\v]"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Class [12,11]
      #|
    ,
  )
}

test "throws on unclosed class" {
  inspect!(test_parse?("[abc"), content="Err(ClassMissingBracket(pos=4))")
}
// #endregion

// #region group
test "should parse group" {
  inspect!(
    test_parse!("(a)"),
    content=
      #|
      #|Number of captures: 2
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Single 97
      #|
    ,
  )
  inspect!(
    test_parse!("(a)(b)"),
    content=
      #|
      #|Number of captures: 3
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Concatenate
      #|    Capture 1
      #|      Single 97
      #|    Capture 2
      #|      Single 98
      #|
    ,
  )
}

test "should parse nested group" {
  inspect!(
    test_parse!("((a)bc)"),
    content=
      #|
      #|Number of captures: 3
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Concatenate
      #|      Capture 2
      #|        Single 97
      #|      Single 98
      #|      Single 99
      #|
    ,
  )
}

test "should parse nested group concat" {
  inspect!(
    test_parse!("((a)(b))"),
    content=
      #|
      #|Number of captures: 4
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Concatenate
      #|      Capture 2
      #|        Single 97
      #|      Capture 3
      #|        Single 98
      #|
    ,
  )
}

test "should parse nested group alt" {
  inspect!(
    test_parse!("((a)|bc)"),
    content=
      #|
      #|Number of captures: 3
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Alternate
      #|      Capture 2
      #|        Single 97
      #|      Concatenate
      #|        Single 98
      #|        Single 99
      #|
    ,
  )
  inspect!(
    test_parse!("((a)|(b))"),
    content=
      #|
      #|Number of captures: 4
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Alternate
      #|      Capture 2
      #|        Single 97
      #|      Capture 3
      #|        Single 98
      #|
    ,
  )
}

test "should parse non-capturing group" {
  inspect!(
    test_parse!("(?:a)"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Group
      #|    Single 97
      #|
    ,
  )
}

test "should parse named group" {
  inspect!(
    test_parse!("(?<group1>a)"),
    content=
      #|
      #|Number of captures: 2
      #|Capture name mapping: {"group1": 1}
      #|Ast:
      #|Capture 0
      #|  Capture 1
      #|    Single 97
      #|
    ,
  )
}

test "throws on unclosed group" {
  inspect!(test_parse?("(abc"), content="Err(GroupMissingParen(pos=4))")
}

test "throws on empty group" {
  inspect!(test_parse?("()"), content="Err(EmptyGroup(pos=1))")
}

test "throws on empty group name" {
  inspect!(test_parse?("(?<>abc)"), content="Err(EmptyGroupName(pos=4))")
}
// #endregion

// #region escape
test "should parse escape" {
  inspect!(
    test_parse!("\\*"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 42
      #|
    ,
  )
  inspect!(
    test_parse!("\\+"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 43
      #|
    ,
  )
  inspect!(
    test_parse!("\\?"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 63
      #|
    ,
  )
  inspect!(
    test_parse!("\\a"),
    content=
      #|
      #|Number of captures: 1
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Single 97
      #|
    ,
  )
}
// #endregion

// #region common
test "should parse common regexp" {
  inspect!(
    test_parse!("^([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})$"),
    content=
      #|
      #|Number of captures: 3
      #|Capture name mapping: {}
      #|Ast:
      #|Capture 0
      #|  Concatenate
      #|    BeginOfLine
      #|    Capture 1
      #|      ClassLoop Greedy {1,} [97-122,65-90,48-57,46,95,37,43,45]
      #|    Single 64
      #|    Capture 2
      #|      Concatenate
      #|        ClassLoop Greedy {1,} [97-122,65-90,48-57,46,45]
      #|        Single 46
      #|        ClassLoop Greedy {2,} [97-122,65-90]
      #|    EndOfLine
      #|
    ,
  )
}
// #endregion
