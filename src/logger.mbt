///|
// Logger for Mocket framework
pub struct Logger {
  enabled : Bool
  level : LogLevel
}

///|
pub enum LogLevel {
  Debug
  Info
  Warn
  Error
}

///|
// 生产环境优化：完全禁用日志以获得零开销
pub fn new_logger(enabled? : Bool = true, level? : LogLevel = Debug) -> Logger {
  { enabled, level }
}

///|
// 生产环境专用：零开销logger（编译时优化）
pub fn new_production_logger() -> Logger {
  { enabled: false, level: Error }
}

///|
// 开发环境专用：全功能logger
pub fn new_debug_logger() -> Logger {
  { enabled: true, level: Debug }
}

///|
// 零成本抽象：使用lazy evaluation避免不必要的字符串构造
pub fn Logger::debug(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Debug) {
    println("🐛 [DEBUG] \{message_fn()}")
  }
}

///|
pub fn Logger::info(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Info) {
    println("ℹ️  [INFO] \{message_fn()}")
  }
}

///|
pub fn Logger::warn(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Warn) {
    println("⚠️  [WARN] \{message_fn()}")
  }
}

///|
pub fn Logger::error(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Error) {
    println("❌ [ERROR] \{message_fn()}")
  }
}

///|
// 便利方法：直接传字符串（性能稍差但使用简单）
pub fn Logger::debug_str(self : Logger, message : String) -> Unit {
  if self.enabled && self.level_allows(Debug) {
    println("🐛 [DEBUG] \{message}")
  }
}

///|
fn Logger::level_allows(self : Logger, target_level : LogLevel) -> Bool {
  match (self.level, target_level) {
    (Debug, _) => true
    (Info, Info) | (Info, Warn) | (Info, Error) => true
    (Warn, Warn) | (Warn, Error) => true
    (Error, Error) => true
    _ => false
  }
}

///|
// 路由相关的专用日志方法 - 零成本抽象版本
pub fn Logger::route_register(
  self : Logger,
  http_method : String,
  path : String,
) -> Unit {
  self.debug(fn() { "🔧 Registering route: \{http_method} \{path}" })
}

///|
pub fn Logger::route_static(
  self : Logger,
  http_method : String,
  path : String,
) -> Unit {
  self.debug(fn() { "📌 Static route: \{http_method} \{path}" })
}

///|
pub fn Logger::route_dynamic(
  self : Logger,
  http_method : String,
  path : String,
) -> Unit {
  self.debug(fn() { "🎯 Dynamic route: \{http_method} \{path}" })
}

///|
pub fn Logger::route_lookup(
  self : Logger,
  http_method : String,
  path : String,
) -> Unit {
  self.debug(fn() { "🔍 Looking for route: \{http_method} \{path}" })
}

///|
pub fn Logger::route_found(
  self : Logger,
  http_method : String,
  path : String,
) -> Unit {
  self.debug(fn() { "✅ Found static route match!" })
  self.debug(fn() { "📝 Request: \{http_method} \{path}" })
}

///|
pub fn Logger::route_not_found(self : Logger, path : String) -> Unit {
  self.debug(fn() { "❌ No static route match for \{path}" })
}

///|
pub fn Logger::routes_available(self : Logger, routes : Array[String]) -> Unit {
  self.debug(fn() { "📋 Found method routes" })
  self.debug(fn() { "🗂️ Available static routes:" })
  routes.iter().each(fn(route) { self.debug(fn() { "  - \{route}" }) })
}

///|
pub fn Logger::route_merge_existing(
  self : Logger,
  http_method : String,
) -> Unit {
  self.debug(fn() { "📝 Adding to existing method routes for \{http_method}" })
}

///|
pub fn Logger::route_merge_new(self : Logger, http_method : String) -> Unit {
  self.debug(fn() { "🆕 Creating new method routes for \{http_method}" })
}

///|
pub fn Logger::route_added(self : Logger, path : String) -> Unit {
  self.debug(fn() { "✅ Added \{path} to existing routes" })
}

///|
pub fn Logger::route_created(self : Logger, path : String) -> Unit {
  self.debug(fn() { "✅ Created new routes and added \{path}" })
}
