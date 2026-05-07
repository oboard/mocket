///|
pub type MiddlewareNext = async () -> &Responder noraise

///|
// 中间件类型：接受 HttpEvent 和 next 函数，返回 HttpBody
pub type Middleware = async (MocketEvent, MiddlewareNext) -> &Responder noraise

///|
priv struct MiddlewareTrieEntry {
  order : Int
  middleware : Middleware
}

///|
priv struct MiddlewareTrieNode {
  middlewares : Array[MiddlewareTrieEntry]
  children : Map[String, MiddlewareTrieNode]
}

///|
fn new_middleware_trie_node() -> MiddlewareTrieNode {
  { middlewares: [], children: {} }
}

///|
// 注册中间件，支持路径匹配
pub fn Mocket::use_middleware(
  self : Mocket,
  middleware : Middleware,
  base_path? : String,
) -> Unit {
  let base_path = base_path.unwrap_or(self.base_path)
  let order = self.middlewares.length()
  self.middlewares.push((base_path, middleware))
  self.middleware_trie.insert_middleware(base_path, order, middleware)
}

///|
fn MiddlewareTrieNode::insert_middleware(
  self : MiddlewareTrieNode,
  base_path : String,
  order : Int,
  middleware : Middleware,
) -> Unit {
  let mut node = self
  for segment in middleware_path_segments(base_path) {
    node = match node.children.get(segment) {
      Some(child) => child
      None => {
        let child = new_middleware_trie_node()
        node.children.set(segment, child)
        child
      }
    }
  }
  node.middlewares.push({ order, middleware })
}

///|
fn middleware_path_segments(path : String) -> Array[String] {
  let path = strip_url_suffix(path)
  let segments = []
  if path == "" || path == "/" {
    return segments
  }
  for segment in path.split("/") {
    let segment = segment.to_owned()
    if segment != "" {
      segments.push(segment)
    }
  }
  segments
}

///|
fn strip_url_suffix(path : String) -> String {
  let query_index = path.find("?").unwrap_or(path.length())
  let hash_index = path.find("#").unwrap_or(path.length())
  let end_index = if query_index < hash_index {
    query_index
  } else {
    hash_index
  }
  path[0:end_index].to_owned()
}

///|
fn insert_middleware_entry(
  entries : Array[MiddlewareTrieEntry],
  entry : MiddlewareTrieEntry,
) -> Unit {
  let mut index = 0
  while index < entries.length() && entries[index].order < entry.order {
    index = index + 1
  }
  entries.insert(index, entry)
}

///|
fn append_sorted_middleware_entries(
  entries : Array[MiddlewareTrieEntry],
  source : Array[MiddlewareTrieEntry],
) -> Unit {
  source.each(entry => insert_middleware_entry(entries, entry))
}

///|
fn Mocket::match_middlewares(self : Mocket, url : String) -> Array[Middleware] {
  let entries = []
  let mut node = self.middleware_trie
  append_sorted_middleware_entries(entries, node.middlewares)
  for segment in middleware_path_segments(url) {
    match node.children.get(segment) {
      Some(child) => {
        node = child
        append_sorted_middleware_entries(entries, node.middlewares)
      }
      None => break
    }
  }
  entries.map(entry => entry.middleware)
}

///|
async fn Mocket::execute_middlewares(
  self : Mocket,
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
  let matched_middlewares = self.match_middlewares(event.req.url)
  execute_middleware_chain(matched_middlewares, 0, event, final_handler)
}

///|
// 执行中间件链，支持路径匹配和洋葱模型
pub async fn execute_middlewares(
  middlewares : Array[(String, Middleware)],
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
  if middlewares.is_empty() {
    return final_handler(event)
  }

  // 过滤出匹配路径的中间件
  let matched_middlewares = []
  middlewares.each(middleware => {
    let (base_path, middleware) = middleware
    // 如果 base_path 为空字符串，则为全局中间件
    // 否则检查请求路径是否匹配 base_path
    if base_path == "" || event.req.url.has_prefix(base_path) {
      matched_middlewares.push(middleware)
    }
  })

  // 递归构建中间件链（洋葱模型）
  execute_middleware_chain(matched_middlewares, 0, event, final_handler)
}

///|
// 递归执行中间件链
async fn execute_middleware_chain(
  middlewares : Array[Middleware],
  index : Int,
  event : MocketEvent,
  final_handler : HttpHandler,
) -> &Responder noraise {
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
