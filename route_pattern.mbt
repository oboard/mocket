///|
/// A single segment of a pre-compiled route pattern.
pub(all) enum RouteSegment {
  /// A literal path segment that must match exactly (e.g. "api", "users")
  Static(String)
  /// A named parameter that captures a single segment (e.g. ":id")
  Param(String)
  /// A single-level wildcard that captures one segment (e.g. "*")
  Wildcard
  /// A multi-level wildcard that captures zero or more segments (e.g. "**")
  GlobStar
} derive(Eq)

///|
impl Show for RouteSegment with output(self, logger) {
  match self {
    Static(s) => logger.write_string(s)
    Param(name) => {
      logger.write_string(":")
      logger.write_string(name)
    }
    Wildcard => logger.write_string("*")
    GlobStar => logger.write_string("**")
  }
}

///|
/// A pre-compiled route pattern, parsed once at registration time.
pub struct CompiledRoute {
  /// The original template string (for debugging/display)
  template : String
  /// Pre-parsed segments (avoids re-splitting on every request)
  segments : Array[RouteSegment]
  /// True if the route is static (no parameters or wildcards)
  is_static : Bool
}

///|
/// Compiles a route template string into a `CompiledRoute`.
pub fn CompiledRoute::compile(template : String) -> CompiledRoute {
  let parts = template.split("/")
  let segments : Array[RouteSegment] = []
  let mut is_static = true
  for part in parts {
    if part == "**" {
      segments.push(GlobStar)
      is_static = false
    } else if part == "*" {
      segments.push(Wildcard)
      is_static = false
    } else if part.view() lexmatch? (":", param_name) {
      segments.push(Param(param_name.to_string()))
      is_static = false
    } else {
      segments.push(Static(part.to_string()))
    }
  }
  { template, segments, is_static }
}

///|
/// Matches a compiled route against a request path, returning extracted parameters or None.
pub fn CompiledRoute::match_path(
  self : CompiledRoute,
  path : String,
) -> Map[String, StringView]? {
  // Static paths: direct comparison (fastest path)
  if self.is_static {
    return if self.template == path { Some({}) } else { None }
  }
  let path_parts = path.split("/").collect()
  match_compiled_segments(self.segments, path_parts, 0, 0, {})
}

///|
fn match_compiled_segments(
  segments : Array[RouteSegment],
  path_parts : Array[StringView],
  seg_idx : Int,
  path_idx : Int,
  params : Map[String, StringView],
) -> Map[String, StringView]? {
  // Both exhausted: match succeeded
  if seg_idx >= segments.length() && path_idx >= path_parts.length() {
    return Some(params)
  }
  // Template exhausted but path remains: no match
  if seg_idx >= segments.length() {
    return None
  }
  // Path exhausted but template remains
  if path_idx >= path_parts.length() {
    return if segments[seg_idx] is GlobStar {
      let trial_params : Map[String, StringView] = {}
      params.each((key, value) => trial_params.set(key, value))
      trial_params.set("_", "")
      match_compiled_segments(
        segments,
        path_parts,
        seg_idx + 1,
        path_idx,
        trial_params,
      )
    } else {
      None
    }
  }
  let path_part = path_parts[path_idx]
  match segments[seg_idx] {
    Static(expected) =>
      if expected == path_part.to_string() {
        match_compiled_segments(
          segments,
          path_parts,
          seg_idx + 1,
          path_idx + 1,
          params,
        )
      } else {
        None
      }
    Param(name) => {
      params.set(name, path_part)
      match_compiled_segments(
        segments,
        path_parts,
        seg_idx + 1,
        path_idx + 1,
        params,
      )
    }
    Wildcard => {
      params.set("_", path_part)
      match_compiled_segments(
        segments,
        path_parts,
        seg_idx + 1,
        path_idx + 1,
        params,
      )
    }
    GlobStar => {
      let mut end_idx = path_idx
      while end_idx <= path_parts.length() {
        let matched_segments : Array[StringView] = []
        let mut i = path_idx
        while i < end_idx {
          matched_segments.push(path_parts[i])
          i = i + 1
        }
        let trial_params : Map[String, StringView] = {}
        params.each((key, value) => trial_params.set(key, value))
        trial_params.set("_", matched_segments.join("/"))
        match
          match_compiled_segments(
            segments,
            path_parts,
            seg_idx + 1,
            end_idx,
            trial_params,
          ) {
          Some(result) => return Some(result)
          None => ()
        }
        end_idx = end_idx + 1
      }
      None
    }
  }
}
