///|
pub async fn[T, E : Error] suspend(
  f : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
pub fn async_run(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
/// # Safety
///
/// You should always `Promise::wait` on any `Promise` you own to attach
/// exception handlers, as long as you are responsible for the control flow
/// (i.e. this `Promise` is not handled by an external JavaScript API).
/// This makes sure that when the operation in the this `Promise` errs out,
/// the error is caught by the MoonBit runtime.
#external
pub type Promise

///|
extern "js" fn Promise::wait_ffi(
  self : Promise,
  on_ok : (Value) -> Unit,
  on_err : (Value) -> Unit,
) -> Unit =
  #| (self, on_ok, on_err) => self.then((t) => on_ok(t), (e) => on_err(e))

///|
pub async fn Promise::wait(self : Promise) -> Value raise {
  suspend(fn(k, ke) { Promise::wait_ffi(self, k, fn(e) { ke(Error_(e)) }) })
}

///|
/// # Safety
///
/// You should always `Promise::wait` on the result of this function to attach
/// exception handlers, as long as you are responsible for the control flow
/// (i.e. the resulting `Promise` is not handled by an external JavaScript API).
/// This makes sure that when `op` errs out, the error is caught by the MoonBit runtime.
///
/// If you don't care about the result of the operation, you can use `spawn_detach` instead.
pub fn[T] Promise::unsafe_new(op : async () -> T raise) -> Promise {
  Promise::new_ffi(fn() { Value::cast_from(op()) })
}

///|
extern "js" fn Promise::new_ffi(op : async () -> Value raise) -> Promise =
  #| (op) => new Promise((k, ke) => op(k, ke))

///|
pub fn[T, E : Error] spawn_detach(op : async () -> T raise E) -> Unit {
  async_run(fn() {
    try op() |> ignore catch {
      _ => ()
    }
  })
}

///|
/// # Note
/// The return type is guaranteed to be a `Promise` of an `Array`, but we omit that detail for simplicity.
pub extern "js" fn Promise::all(promises : Array[Promise]) -> Promise = "(ps) => Promise.all(ps)"

///|
/// Wraps each given `async fn` in a `Promise` and waits for all of them to resolve.
pub async fn[T] async_all(ops : Array[async () -> T raise]) -> Array[T] raise {
  async_all_raw(ops.map(fn(op) { async fn() raise { Value::cast_from(op()) } })).map(
    Value::cast,
  )
}

///|
async fn async_all_raw(
  ops : Array[async () -> Value raise],
) -> Array[Value] raise {
  Promise::all(ops.map(Promise::unsafe_new)).wait().cast()
}

///|
pub fn async_test(op : async () -> Unit raise) -> Unit {
  async_run(async fn() noraise {
    op() catch {
      e => {
        println("ERROR in `async_test`: \{e}")
        panic()
      }
    }
  })
}
