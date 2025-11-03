///|
// 中间件类型：接受 HttpEvent 和 next 函数，返回 HttpBody
pub type Middleware = async (HttpEvent, async () -> HttpBody noraise) -> HttpBody noraise

///|
// 注册中间件，支持路径匹配
pub fn Mocket::use_middleware(
  self : Mocket,
  middleware : Middleware,
  base_path? : String,
) -> Unit {
  let base_path = base_path.unwrap_or(self.base_path)
  // 将中间件和路径信息一起存储
  self.middlewares.push((base_path, middleware))
}

///|
// 执行中间件链，支持路径匹配和洋葱模型
pub async fn execute_middlewares(
  middlewares : Array[(String, Middleware)],
  event : HttpEvent,
  final_handler : async (HttpEvent) -> HttpBody noraise,
) -> HttpBody noraise {
  // 过滤出匹配路径的中间件
  let matched_middlewares = []
  for i = 0; i < middlewares.length(); i = i + 1 {
    let (base_path, middleware) = middlewares[i]
    // 如果 base_path 为空字符串，则为全局中间件
    // 否则检查请求路径是否匹配 base_path
    if base_path == "" || event.req.url.has_prefix(base_path) {
      matched_middlewares.push(middleware)
    }
  }

  // 递归构建中间件链（洋葱模型）
  execute_middleware_chain(matched_middlewares, 0, event, final_handler)
}

///|
// 递归执行中间件链
async fn execute_middleware_chain(
  middlewares : Array[Middleware],
  index : Int,
  event : HttpEvent,
  final_handler : async (HttpEvent) -> HttpBody noraise,
) -> HttpBody noraise {
  if index >= middlewares.length() {
    // 所有中间件都执行完毕，调用最终处理器
    final_handler(event)
  } else {
    // 执行当前中间件
    let current_middleware = middlewares[index]
    let next = async fn() noraise {
      execute_middleware_chain(middlewares, index + 1, event, final_handler)
    }
    current_middleware(event, next)
  }
}
