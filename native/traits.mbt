///|
trait Sized {
  size() -> Int64
}

///|
trait Setter {
  set(Ptr[Self], Self) -> Unit
}

///|
trait Getter {
  get(ConstPtr[Self]) -> Self
}
