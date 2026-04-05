///|
let global_id_count : Ref[Int] = @ref.new(0)

///|
struct Id(Int) derive(Eq, Hash, Compare, Show)

///|
fn next_id() -> Int {
  let id = global_id_count.val
  global_id_count.val += 1
  id
}

///|
pub fn Id::new() -> Id {
  next_id()
}

///|
struct InstId(Int) derive(Eq, Hash)

///|
pub fn InstId::new() -> InstId {
  next_id()
}
