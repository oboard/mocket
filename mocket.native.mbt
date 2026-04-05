///|
fn serve_ffi(mocket : Mocket, port~ : Int) -> Unit {
  async_run(async fn() noraise {
    mocket.serve_async(port~) catch {
      err => abort("Mocket native server failed: \{err}")
    }
  })
}
