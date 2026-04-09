/// A radix tree node for efficient route matching.
///
/// Each node represents a path segment. Children are organized by type:
/// - `static_children`: exact string match children (Map lookup)
/// - `param_child`: a single `:name` child (captures one segment)
/// - `wildcard_child`: a `*` child (captures one segment into `_`)
/// - `globstar_child`: a `**` child (captures remaining segments into `_`)
/// - `handler`: the handler registered at this node (if any)

///|
priv struct RadixNode[T] {
  mut handler : T?
  static_children : Map[String, RadixNode[T]]
  mut param_child : (String, RadixNode[T])?
  mut wildcard_child : RadixNode[T]?
  mut globstar_child : T?
}

///|
fn[T] RadixNode::new() -> RadixNode[T] {
  {
    handler: None,
    static_children: {},
    param_child: None,
    wildcard_child: None,
    globstar_child: None,
  }
}

/// Insert a compiled route into the radix tree.

///|
fn[T] RadixNode::insert(
  self : RadixNode[T],
  route : CompiledRoute,
  handler : T,
) -> Unit {
  insert_segments(self, route.segments, 0, handler)
}

///|
fn[T] insert_segments(
  node : RadixNode[T],
  segments : Array[RouteSegment],
  idx : Int,
  handler : T,
) -> Unit {
  if idx >= segments.length() {
    node.handler = Some(handler)
    return
  }
  match segments[idx] {
    Static(s) => {
      let child = match node.static_children.get(s) {
        Some(existing) => existing
        None => {
          let new_node = RadixNode::new()
          node.static_children.set(s, new_node)
          new_node
        }
      }
      insert_segments(child, segments, idx + 1, handler)
    }
    Param(name) => {
      let (_, child) = match node.param_child {
        Some((existing_name, existing_child)) => {
          // Conflict detection: if two routes at the same tree position
          // use different param names (e.g. /users/:id and /users/:name),
          // the second handler would extract the param under the wrong key.
          // Warn at registration time so users catch this at startup.
          if existing_name != name {
            println(
              "[crescent warning] route param name conflict: existing `:\{existing_name}` vs new `:\{name}` at the same tree position. Using `\{existing_name}`. Rename one to match.",
            )
          }
          (existing_name, existing_child)
        }
        None => {
          let new_node = RadixNode::new()
          let pair = (name, new_node)
          node.param_child = Some(pair)
          pair
        }
      }
      insert_segments(child, segments, idx + 1, handler)
    }
    Wildcard => {
      let child = match node.wildcard_child {
        Some(existing) => existing
        None => {
          let new_node = RadixNode::new()
          node.wildcard_child = Some(new_node)
          new_node
        }
      }
      insert_segments(child, segments, idx + 1, handler)
    }
    GlobStar =>
      // GlobStar is always terminal or near-terminal; store handler directly
      if idx + 1 >= segments.length() {
        node.globstar_child = Some(handler)
      } else {
        // GlobStar with trailing segments (e.g. /files/**/meta) - fall back
        // to the compiled route matching for this edge case
        node.globstar_child = Some(handler)
      }
  }
}

/// Search the radix tree for a matching handler.
/// Returns the handler and extracted parameters on match.

///|
fn[T] RadixNode::search(
  self : RadixNode[T],
  path : String,
) -> (T, Map[String, StringView])? {
  let parts = path.split("/").collect()
  search_segments(self, parts, 0, {})
}

///|
fn[T] search_segments(
  node : RadixNode[T],
  parts : Array[StringView],
  idx : Int,
  params : Map[String, StringView],
) -> (T, Map[String, StringView])? {
  // All parts consumed: check for handler at this node
  if idx >= parts.length() {
    match node.handler {
      Some(handler) => return Some((handler, params))
      None => ()
    }
    // Check globstar (matches zero segments)
    match node.globstar_child {
      Some(handler) => {
        params.set("_", "")
        return Some((handler, params))
      }
      None => ()
    }
    return None
  }
  let part = parts[idx]
  // 1. Try static children first (exact match, fastest)
  // Use get_from_string to avoid allocating a String from the StringView.
  match Map::get_from_string(node.static_children, part) {
    Some(child) =>
      match search_segments(child, parts, idx + 1, params) {
        Some(result) => return Some(result)
        None => ()
      }
    None => ()
  }
  // 2. Try param child (:name)
  match node.param_child {
    Some((name, child)) => {
      let saved = params.get(name)
      params.set(name, part)
      match search_segments(child, parts, idx + 1, params) {
        Some(result) => return Some(result)
        None =>
          // Backtrack
          match saved {
            Some(v) => params.set(name, v)
            None => ignore(params.remove(name))
          }
      }
    }
    None => ()
  }
  // 3. Try wildcard child (*)
  match node.wildcard_child {
    Some(child) => {
      let saved = params.get("_")
      params.set("_", part)
      match search_segments(child, parts, idx + 1, params) {
        Some(result) => return Some(result)
        None =>
          match saved {
            Some(v) => params.set("_", v)
            None => ignore(params.remove("_"))
          }
      }
    }
    None => ()
  }
  // 4. Try globstar child (**)
  match node.globstar_child {
    Some(handler) => {
      // GlobStar matches the rest of the path
      let remaining : Array[StringView] = []
      let mut i = idx
      while i < parts.length() {
        remaining.push(parts[i])
        i = i + 1
      }
      params.set("_", remaining.join("/"))
      return Some((handler, params))
    }
    None => ()
  }
  None
}

/// A per-method radix tree router that provides O(path_length) route lookup.

///|
struct RadixRouter[T] {
  // Per-method trees
  trees : Map[String, RadixNode[T]]
  // Fallback for routes registered with CompiledRoute (globstar with trailing segments)
  fallback_routes : Map[String, Array[(CompiledRoute, T)]]
}

///|
/// Creates a new empty radix router with no registered routes.
pub fn[T] RadixRouter::new() -> RadixRouter[T] {
  { trees: {}, fallback_routes: {} }
}

///|
fn[T] RadixRouter::get_or_create_tree(
  self : RadixRouter[T],
  http_method : String,
) -> RadixNode[T] {
  match self.trees.get(http_method) {
    Some(tree) => tree
    None => {
      let tree = RadixNode::new()
      self.trees.set(http_method, tree)
      tree
    }
  }
}

///|
/// Inserts a compiled route for a given HTTP method.
pub fn[T] RadixRouter::insert(
  self : RadixRouter[T],
  http_method : String,
  route : CompiledRoute,
  handler : T,
) -> Unit {
  // Check if this route has a globstar with trailing segments (e.g. /files/**/meta)
  // These are rare and need fallback matching
  let has_trailing_after_globstar = has_globstar_with_trailing(route.segments)
  if has_trailing_after_globstar {
    match self.fallback_routes.get(http_method) {
      Some(routes) => routes.push((route, handler))
      None => self.fallback_routes.set(http_method, [(route, handler)])
    }
  } else {
    let tree = self.get_or_create_tree(http_method)
    tree.insert(route, handler)
  }
}

///|
fn has_globstar_with_trailing(segments : Array[RouteSegment]) -> Bool {
  let mut found_globstar = false
  for seg in segments {
    if found_globstar {
      return true
    }
    if seg is GlobStar {
      found_globstar = true
    }
  }
  false
}

///|
/// Merges all routes from another router into this one.
pub fn[T] RadixRouter::merge(
  self : RadixRouter[T],
  other : RadixRouter[T],
) -> Unit {
  // Merge radix trees by re-inserting all routes
  // We traverse the other's trees and collect routes, then insert them
  other.trees.each((http_method, tree) => {
    let target = self.get_or_create_tree(http_method)
    merge_nodes(target, tree)
  })
  // Merge fallback routes
  other.fallback_routes.each((http_method, routes) => {
    match self.fallback_routes.get(http_method) {
      Some(existing) => existing.append(routes)
      None => self.fallback_routes.set(http_method, routes)
    }
  })
}

///|
fn[T] merge_nodes(target : RadixNode[T], source : RadixNode[T]) -> Unit {
  // Merge handler
  match source.handler {
    Some(h) => target.handler = Some(h)
    None => ()
  }
  // Merge static children
  source.static_children.each((key, source_child) => {
    match target.static_children.get(key) {
      Some(target_child) => merge_nodes(target_child, source_child)
      None => target.static_children.set(key, source_child)
    }
  })
  // Merge param child
  match source.param_child {
    Some((name, source_child)) =>
      match target.param_child {
        Some((_, target_child)) => merge_nodes(target_child, source_child)
        None => target.param_child = Some((name, source_child))
      }
    None => ()
  }
  // Merge wildcard child
  match source.wildcard_child {
    Some(source_child) =>
      match target.wildcard_child {
        Some(target_child) => merge_nodes(target_child, source_child)
        None => target.wildcard_child = Some(source_child)
      }
    None => ()
  }
  // Merge globstar
  match source.globstar_child {
    Some(h) => target.globstar_child = Some(h)
    None => ()
  }
}

///|
/// Searches for a handler matching the given HTTP method and path.
pub fn[T] RadixRouter::search(
  self : RadixRouter[T],
  http_method : String,
  path : String,
) -> (T, Map[String, StringView])? {
  // Try radix tree first
  match self.trees.get(http_method) {
    Some(tree) =>
      match tree.search(path) {
        Some(result) => return Some(result)
        None => ()
      }
    None => ()
  }
  // Fall back to linear scan for complex patterns
  match self.fallback_routes.get(http_method) {
    Some(routes) =>
      for route in routes {
        let (compiled, handler) = route
        match compiled.match_path(path) {
          Some(params) => return Some((handler, params))
          None => ()
        }
      }
    None => ()
  }
  None
}
