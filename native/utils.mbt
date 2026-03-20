///|
pub fn[V, E : Error] try_finally(
  f : () -> V raise E,
  finally_~ : () -> Unit,
) -> V raise E {
  try {
    let v = f()
    finally_()
    v
  } catch {
    _ as e => {
      finally_()
      raise e
    }
  }
}
