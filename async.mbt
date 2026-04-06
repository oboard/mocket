///|
/// Runs an async function to completion, blocking the current thread.
pub fn async_run(f : async () -> Unit noraise) -> Unit = "%async.run"
