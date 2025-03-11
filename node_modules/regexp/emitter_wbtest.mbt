///|
fn test_emit(ast : Ast) -> Program {
  Emitter::new(ast).emit()
}

test "should emit single" {
  inspect!(
    test_parse!("a") |> test_emit(),
    content=
      #|0 BranchLazy 7
      #|2 SetMark
      #|3 Single 97
      #|5 CaptureMark 0
      #|7 Stop
      #|
    ,
  )
}

test "should emit concat" {
  inspect!(
    test_parse!("abc") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 Single 97
      #|5 Single 98
      #|7 Single 99
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
}

test "should emit alt" {
  inspect!(
    test_parse!("a|b|c") |> test_emit(),
    content=
      #|0 BranchLazy 19
      #|2 SetMark
      #|3 BranchLazy 9
      #|5 Single 97
      #|7 Goto 17
      #|9 BranchLazy 15
      #|11 Single 98
      #|13 Goto 17
      #|15 Single 99
      #|17 CaptureMark 0
      #|19 Stop
      #|
    ,
  )
}

test "should emit loop" {
  inspect!(
    test_parse!("a*") |> test_emit(),
    content=
      #|0 BranchLazy 8
      #|2 SetMark
      #|3 SingleLoop 97 2147483647
      #|6 CaptureMark 0
      #|8 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a+") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 SingleRepeat 97 1
      #|6 SingleLoop 97 2147483647
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a?") |> test_emit(),
    content=
      #|0 BranchLazy 8
      #|2 SetMark
      #|3 SingleLoop 97 1
      #|6 CaptureMark 0
      #|8 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a{3}") |> test_emit(),
    content=
      #|0 BranchLazy 8
      #|2 SetMark
      #|3 SingleRepeat 97 3
      #|6 CaptureMark 0
      #|8 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a{1,3}") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 SingleRepeat 97 1
      #|6 SingleLoop 97 2
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a{1,}") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 SingleRepeat 97 1
      #|6 SingleLoop 97 2147483647
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a*?") |> test_emit(),
    content=
      #|0 BranchLazy 8
      #|2 SetMark
      #|3 SingleLazy 97 2147483647
      #|6 CaptureMark 0
      #|8 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a+?") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 SingleRepeat 97 1
      #|6 SingleLazy 97 2147483647
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a??") |> test_emit(),
    content=
      #|0 BranchLazy 8
      #|2 SetMark
      #|3 SingleLazy 97 1
      #|6 CaptureMark 0
      #|8 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("a{1,2}?") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 SingleRepeat 97 1
      #|6 SingleLazy 97 1
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
}

test "should emit class" {
  inspect!(
    test_parse!("[abc]") |> test_emit(),
    content=
      #|0 BranchLazy 7
      #|2 SetMark
      #|3 Class [97,98,99]
      #|5 CaptureMark 0
      #|7 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("[^abc]") |> test_emit(),
    content=
      #|0 BranchLazy 7
      #|2 SetMark
      #|3 Class [^97,98,99]
      #|5 CaptureMark 0
      #|7 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("[a-zA-Z0-9]") |> test_emit(),
    content=
      #|0 BranchLazy 7
      #|2 SetMark
      #|3 Class [97-122,65-90,48-57]
      #|5 CaptureMark 0
      #|7 Stop
      #|
    ,
  )
}

test "should emit group" {
  inspect!(
    test_parse!("(abc)") |> test_emit(),
    content=
      #|0 BranchLazy 14
      #|2 SetMark
      #|3 SetMark
      #|4 Single 97
      #|6 Single 98
      #|8 Single 99
      #|10 CaptureMark 1
      #|12 CaptureMark 0
      #|14 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("((a)bc)") |> test_emit(),
    content=
      #|0 BranchLazy 17
      #|2 SetMark
      #|3 SetMark
      #|4 SetMark
      #|5 Single 97
      #|7 CaptureMark 2
      #|9 Single 98
      #|11 Single 99
      #|13 CaptureMark 1
      #|15 CaptureMark 0
      #|17 Stop
      #|
    ,
  )
  inspect!(
    test_parse!("((a)|(b))") |> test_emit(),
    content=
      #|0 BranchLazy 22
      #|2 SetMark
      #|3 SetMark
      #|4 BranchLazy 13
      #|6 SetMark
      #|7 Single 97
      #|9 CaptureMark 2
      #|11 Goto 18
      #|13 SetMark
      #|14 Single 98
      #|16 CaptureMark 3
      #|18 CaptureMark 1
      #|20 CaptureMark 0
      #|22 Stop
      #|
    ,
  )
}

test "should emit non-capturing group" {
  inspect!(
    test_parse!("(?:abc)") |> test_emit(),
    content=
      #|0 BranchLazy 11
      #|2 SetMark
      #|3 Single 97
      #|5 Single 98
      #|7 Single 99
      #|9 CaptureMark 0
      #|11 Stop
      #|
    ,
  )
}

test "should emit named group" {
  inspect!(
    test_parse!("(?<group1>abc)") |> test_emit(),
    content=
      #|0 BranchLazy 14
      #|2 SetMark
      #|3 SetMark
      #|4 Single 97
      #|6 Single 98
      #|8 Single 99
      #|10 CaptureMark 1
      #|12 CaptureMark 0
      #|14 Stop
      #|
    ,
  )
}

test "should emit common pattern" {
  let ast = test_parse!("^([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})$")
  inspect!(
    test_emit(ast),
    content=
      #|0 BranchLazy 35
      #|2 SetMark
      #|3 BeginOfInput
      #|4 SetMark
      #|5 ClassRepeat [97-122,65-90,48-57,46,95,37,43,45] 1
      #|8 ClassLoop [97-122,65-90,48-57,46,95,37,43,45] 2147483647
      #|11 CaptureMark 1
      #|13 Single 64
      #|15 SetMark
      #|16 ClassRepeat [97-122,65-90,48-57,46,45] 1
      #|19 ClassLoop [97-122,65-90,48-57,46,45] 2147483647
      #|22 Single 46
      #|24 ClassRepeat [97-122,65-90] 2
      #|27 ClassLoop [97-122,65-90] 2147483647
      #|30 CaptureMark 2
      #|32 EndOfInput
      #|33 CaptureMark 0
      #|35 Stop
      #|
    ,
  )
}
