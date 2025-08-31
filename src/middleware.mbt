///|
// 注册中间件，支持路径匹配
pub fn use_middleware(
  self : Mocket,
  middleware : async (HttpEvent) -> Unit noraise,
  base_path? : String,
) -> Unit {
  let base_path = base_path.unwrap_or(self.base_path)
  // 将中间件和路径信息一起存储
  self.middlewares.push((base_path, middleware))
}

///|
// 执行中间件链，支持路径匹配
fn execute_middlewares(
  middlewares : Array[(String, async (HttpEvent) -> Unit noraise)],
  event : HttpEvent,
) -> Unit {
  // 优化：使用迭代而不是递归，避免栈溢出
  let mut i = 0
  while i < middlewares.length() {
    let (base_path, middleware) = middlewares[i]
    // 如果 base_path 为空字符串，则为全局中间件
    // 否则检查请求路径是否匹配 base_path
    if base_path == "" || event.req.url.has_prefix(base_path) {
      run(fn() { middleware(event) })
    }
    i = i + 1
  }
}
