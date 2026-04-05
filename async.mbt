///|
pub fn async_run(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
/// `suspend` pauses the current coroutine.
/// It accepts a callback that controls the suspended coroutine.
pub async fn[T, E : Error] suspend(
  // `f` is the callback that controls the suspended coroutine.
  f : (
    // First argument: resumes the suspended coroutine with a value.
    (T) -> Unit,
    // Second argument: cancels the suspended coroutine.
    // Cancellation manifests as an error thrown at the suspension point.
    (E) -> Unit,
  ) -> Unit,
) -> T raise E = "%async.suspend"
