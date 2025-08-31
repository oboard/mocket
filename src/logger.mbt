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
pub fn debug(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Debug) {
    println("🐛 [DEBUG] \{message_fn()}")
  }
}

///|
pub fn info(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Info) {
    println("ℹ️  [INFO] \{message_fn()}")
  }
}

///|
pub fn warn(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Warn) {
    println("⚠️  [WARN] \{message_fn()}")
  }
}

///|
pub fn error(self : Logger, message_fn : () -> String) -> Unit {
  if self.enabled && self.level_allows(Error) {
    println("❌ [ERROR] \{message_fn()}")
  }
}

///|
// 便利方法：直接传字符串（性能稍差但使用简单）
pub fn debug_str(self : Logger, message : String) -> Unit {
  if self.enabled && self.level_allows(Debug) {
    println("🐛 [DEBUG] \{message}")
  }
}

///|
fn level_allows(self : Logger, target_level : LogLevel) -> Bool {
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
pub fn route_register(self : Logger, method_ : String, path : String) -> Unit {
  self.debug(fn() { "🔧 Registering route: \{method_} \{path}" })
}

///|
pub fn route_static(self : Logger, method_ : String, path : String) -> Unit {
  self.debug(fn() { "📌 Static route: \{method_} \{path}" })
}

///|
pub fn route_dynamic(self : Logger, method_ : String, path : String) -> Unit {
  self.debug(fn() { "🎯 Dynamic route: \{method_} \{path}" })
}

///|
pub fn route_lookup(self : Logger, method_ : String, path : String) -> Unit {
  self.debug(fn() { "🔍 Looking for route: \{method_} \{path}" })
}

///|
pub fn route_found(self : Logger, method_ : String, path : String) -> Unit {
  self.debug(fn() { "✅ Found static route match!" })
  self.debug(fn() { "📝 Request: \{method_} \{path}" })
}

///|
pub fn route_not_found(self : Logger, path : String) -> Unit {
  self.debug(fn() { "❌ No static route match for \{path}" })
}

///|
pub fn routes_available(self : Logger, routes : Array[String]) -> Unit {
  self.debug(fn() { "📋 Found method routes" })
  self.debug(fn() { "🗂️ Available static routes:" })
  routes.iter().each(fn(route) { self.debug(fn() { "  - \{route}" }) })
}

///|
pub fn route_merge_existing(self : Logger, method_ : String) -> Unit {
  self.debug(fn() { "📝 Adding to existing method routes for \{method_}" })
}

///|
pub fn route_merge_new(self : Logger, method_ : String) -> Unit {
  self.debug(fn() { "🆕 Creating new method routes for \{method_}" })
}

///|
pub fn route_added(self : Logger, path : String) -> Unit {
  self.debug(fn() { "✅ Added \{path} to existing routes" })
}

///|
pub fn route_created(self : Logger, path : String) -> Unit {
  self.debug(fn() { "✅ Created new routes and added \{path}" })
}
