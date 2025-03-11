///|
struct MatchResult {
  success : Bool
  captures : Array[String]
  named_captures : Map[String, String]
} derive(Show)

///|
pub fn success(self : MatchResult) -> Bool {
  self.success
}

///|
pub fn captures(self : MatchResult) -> Array[String] {
  self.captures
}

///|
pub fn named_captures(self : MatchResult) -> Map[String, String] {
  self.named_captures
}

test "get captures" {
  let res = {
    success: true,
    captures: ["123456789", "123", "456", "789"],
    named_captures: { "a": "123", "b": "456", "c": "789" },
  }
  inspect!(res.success(), content="true")
  inspect!(
    res.captures,
    content=
      #|["123456789", "123", "456", "789"]
    ,
  )
  inspect!(
    res.named_captures(),
    content=
      #|{"a": "123", "b": "456", "c": "789"}
    ,
  )
}
