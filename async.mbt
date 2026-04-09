///|
/// Runs an async function to completion, blocking the current thread.
/// Prefer `async fn main` over calling this directly.
pub fn async_run(f : async () -> Unit noraise) -> Unit {
  @async.run_async_main(async fn() { f() })
}
