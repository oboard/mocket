///|
priv enum OpCode {
  Nop
  Stop
  // Match operations.
  Single // char
  NotSingle // char
  Class // class_index
  SingleRepeat // char, count
  NotSingleRepeat // char, count
  ClassRepeat // class_index, count
  SingleLoop // char, max_count
  NotSingleLoop // char, max_count
  ClassLoop // class_index, max_count
  SingleLazy // char, max_count
  NotSingleLazy // char, max_count
  ClassLazy // class_index, max_count
  BeginOfInput
  EndOfInput
  // Control operations.
  Goto // addr
  BranchLazy // addr
  BranchMark // addr
  BranchMarkLazy // addr
  NullCount // count
  SetCount // count
  BranchCount // addr, max_count
  BranchCountLazy // addr, max_count
  NullMark
  SetMark
  CaptureMark // capture_index
  GetMark
} derive(Show)

///|
fn to_bytecode(self : OpCode) -> Int {
  match self {
    Nop => -1
    Stop => 0
    Single => 1
    NotSingle => 2
    Class => 3
    SingleRepeat => 4
    NotSingleRepeat => 5
    ClassRepeat => 6
    SingleLoop => 7
    NotSingleLoop => 8
    ClassLoop => 9
    SingleLazy => 10
    NotSingleLazy => 11
    ClassLazy => 12
    BeginOfInput => 13
    EndOfInput => 14
    Goto => 15
    BranchLazy => 16
    BranchMark => 17
    BranchMarkLazy => 18
    NullCount => 19
    SetCount => 20
    BranchCount => 21
    BranchCountLazy => 22
    NullMark => 23
    SetMark => 24
    CaptureMark => 25
    GetMark => 26
  }
}

///|
fn OpCode::from_bytecode(bytecode : Int) -> OpCode {
  match bytecode {
    0 => Stop
    1 => Single
    2 => NotSingle
    3 => Class
    4 => SingleRepeat
    5 => NotSingleRepeat
    6 => ClassRepeat
    7 => SingleLoop
    8 => NotSingleLoop
    9 => ClassLoop
    10 => SingleLazy
    11 => NotSingleLazy
    12 => ClassLazy
    13 => BeginOfInput
    14 => EndOfInput
    15 => Goto
    16 => BranchLazy
    17 => BranchMark
    18 => BranchMarkLazy
    19 => NullCount
    20 => SetCount
    21 => BranchCount
    22 => BranchCountLazy
    23 => NullMark
    24 => SetMark
    25 => CaptureMark
    26 => GetMark
    _ => panic()
  }
}

///| Returns true if this operation needs to backtrack.
fn need_backtrack(self : OpCode) -> Bool {
  match self {
    SingleLoop
    | SingleLazy
    | NotSingleLoop
    | NotSingleLazy
    | ClassLoop
    | ClassLazy
    | BranchLazy
    | BranchMark
    | BranchMarkLazy
    | NullCount
    | SetCount
    | BranchCount
    | BranchCountLazy
    | SetMark
    | CaptureMark
    | Goto => true
    _ => false
  }
}
