// URI parser implementation following RFC 3986

///|
/// Represents the host component of a URI, which is either an IPv6 address
/// enclosed in brackets or a registered name (including IPv4 addresses).
pub enum Host {
  IPv6Address(BytesView)
  RegName(BytesView)
} derive(Eq, Debug)

///|
impl Show for Host with output(self, logger) {
  match self {
    IPv6Address(addr) => {
      logger.write_string("IPv6Address(")
      logger.write_object(addr)
      logger.write_string(")")
    }
    RegName(name) => {
      logger.write_string("RegName(")
      logger.write_object(name)
      logger.write_string(")")
    }
  }
}

///|
/// The authority component of a URI, comprising an optional userinfo, a host,
/// and an optional port number (e.g. `user:pass@example.com:8080`).
pub struct Authority {
  mut userinfo : BytesView?
  mut host : Host
  mut port : Int?
} derive(Eq, Debug)

///|
impl Show for Authority with output(self, logger) {
  logger.write_string("{userinfo: ")
  logger.write_object(self.userinfo)
  logger.write_string(", host: ")
  logger.write_object(self.host)
  logger.write_string(", port: ")
  logger.write_object(self.port)
  logger.write_string("}")
}

///|
/// A parsed URI following RFC 3986, containing an optional scheme, authority,
/// path segments, query, and fragment.
pub struct Uri {
  mut scheme : BytesView?
  mut authority : Authority?
  path : Array[BytesView]
  mut query : BytesView?
  mut fragment : BytesView?
} derive(Eq, Debug)

///|
/// Errors that can occur during URI parsing, indicating the specific component
/// that failed validation.
pub suberror ParseError {
  InvalidScheme(BytesView)
  InvalidHeirPart(BytesView)
  InvalidPercentEncoding(BytesView)
  MissingColon
  MissingScheme
  InvalidSegment(BytesView)
  InvalidSchemeOrSegment(BytesView)
  Invalid(BytesView)
}

///|
fn BytesView::slice_until(self : BytesView, other : BytesView) -> BytesView {
  self.data()[self.start_offset():other.start_offset()]
}

// RFC 3986 Character Classification Functions

///|
fn is_alpha_byte(b : Byte) -> Bool {
  (b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z')
}

///|
fn is_digit_byte(b : Byte) -> Bool {
  b >= '0' && b <= '9'
}

///|
fn is_hexdig_byte(b : Byte) -> Bool {
  is_digit_byte(b) || (b >= 'A' && b <= 'F') || (b >= 'a' && b <= 'f')
}

///|
fn is_unreserved_byte(b : Byte) -> Bool {
  is_alpha_byte(b) ||
  is_digit_byte(b) ||
  b == '-' ||
  b == '.' ||
  b == '_' ||
  b == '~'
}

///|
fn is_gen_delim_byte(b : Byte) -> Bool {
  b == ':' ||
  b == '/' ||
  b == '?' ||
  b == '#' ||
  b == '[' ||
  b == ']' ||
  b == '@'
}

///|
fn is_sub_delim_byte(b : Byte) -> Bool {
  b == '!' ||
  b == '$' ||
  b == '&' ||
  b == '\'' ||
  b == '(' ||
  b == ')' ||
  b == '*' ||
  b == '+' ||
  b == ',' ||
  b == ';' ||
  b == '='
}

///|
fn is_pchar_byte(b : Byte) -> Bool {
  is_unreserved_byte(b) || is_sub_delim_byte(b) || b == ':' || b == '@'
}

// RFC 3986 Parsing Functions

// URI-reference = scheme ":" "//" authority path-abempty [ "?" query ] [ "#" fragment ]
//               / scheme ":" "/" [ segment-nz *( "/" segment ) ] [ "?" query ] [ "#" fragment ]
//               / scheme ":" segment-nz *( "/" segment ) [ "?" query ] [ "#" fragment ]
//               / scheme ":" [ "?" query ] [ "#" fragment ]
//               / "//" authority path-abempty [ "?" query ] [ "#" fragment ]
//               / "/" [ segment-nz *( "/" segment ) ] [ "?" query ] [ "#" fragment ]
//               / segment-nz-nc *( "/" segment ) [ "?" query ] [ "#" fragment ]
//               / [ "?" query ] [ "#" fragment ]

///|
fn parse_scheme_or_segment_nz_nc(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let segment = source
  for s = source {
    match s {
      [':', .. k] as s => {
        uri.scheme = Some(source.slice_until(s))
        return parse_hier_part_then_query(k, uri)
      }
      ['/', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_path_abempty_then_query(k, uri)
      }
      ['?', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_query_then_fragment(k, uri)
      }
      ['#', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_query_then_fragment(k, uri)
      }
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) || b == '@' =>
        continue k
      _ => raise InvalidSchemeOrSegment(source)
    }
  }
}

///|
fn parse_uri_reference(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. "//", .. k] => {
      // relative-ref > relative-part > "//" authority path-abempty
      let k = parse_authority(k, uri)
      parse_path_abempty_then_query(k, uri)
    }
    ['/', .. k] =>
      // relative-ref > relative-part > "/" [ segment-nz *( "/" segment ) ] [ "?" query ] [ "#" fragment ]
      parse_path_abempty_then_query(k, uri)
    ['?', .. k] =>
      // relative-ref > relative-part > "?" query
      parse_query_then_fragment(k, uri)
    ['#', .. k] =>
      // relative-ref > relative-part > "#" fragment
      parse_fragment(k, uri)
    [..] as s => parse_scheme_or_segment_nz_nc(s, uri)
  }
}

///|
/// Parses a URI-reference from raw bytes following RFC 3986, returning a fully
/// populated `Uri` structure or raising a `ParseError` on invalid input.
pub fn Uri::parse(source : BytesView) -> Uri raise ParseError {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  let source = parse_uri_reference(source, uri)
  if !(source is []) {
    raise Invalid(source)
  }
  uri
}

///|
fn parse_scheme(source : BytesView, uri : Uri) -> BytesView raise ParseError {
  match source {
    [b, .. k] if is_alpha_byte(b) =>
      for s = k {
        match s {
          [b, .. s] if is_alpha_byte(b) ||
            is_digit_byte(b) ||
            b == '+' ||
            b == '-' ||
            b == '.' => continue s
          [':', .. k] as s => {
            uri.scheme = Some(source.slice_until(s))
            return k
          }
          [_, ..] as s => raise InvalidScheme(s)
          [] => raise MissingColon
        }
      }
    [_, ..] as s => raise InvalidScheme(s)
    [] => raise MissingScheme
  }
}

///|
fn parse_percent_encoding(source : BytesView) -> BytesView raise ParseError {
  match source {
    [
      '0'..='9'
      | 'A'..='F'
      | 'a'..='f',
      '0'..='9'
      | 'A'..='F'
      | 'a'..='f',
      .. source,
    ] => source
    [..] => raise InvalidPercentEncoding(source)
  }
}

///|
fn parse_userinfo(
  source : BytesView,
  authority : Authority,
) -> BytesView raise ParseError {
  let start = source
  for s = source {
    match s {
      ['@', .. k] as s => {
        authority.userinfo = Some(start.slice_until(s))
        return k
      }
      ['%', .. k] => continue parse_percent_encoding(k)
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) || b == ':' =>
        continue k
      [_, ..] as s => raise InvalidHeirPart(s)
      [] as s => return s
    }
  }
}

///|
fn parse_reg_name(
  source : BytesView,
  authority : Authority,
) -> BytesView raise ParseError {
  for s = source {
    match s {
      ['%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) => continue k
      _ as s => {
        authority.host = RegName(source.slice_until(s))
        return s
      }
    }
  }
}

///|
fn parse_ipv6_address(
  source : BytesView,
  authority : Authority,
) -> BytesView raise ParseError {
  // Simplified IPv6 parsing - match until ']'
  for s = source {
    match s {
      [']', .. k] as s => {
        authority.host = IPv6Address(source.slice_until(s))
        return k
      }
      [b, .. s] if is_hexdig_byte(b) || b == ':' || b == '.' => continue s
      _ as s => raise InvalidHeirPart(s)
    }
  }
}

///|
fn parse_host(
  source : BytesView,
  authority : Authority,
) -> BytesView raise ParseError {
  // Try IP literal first
  match source {
    ['[', .. k] => parse_ipv6_address(k, authority)
    _ =>
      // Try IPv4 address, fallback to reg-name
      parse_reg_name(source, authority)
  }
}

///|
fn parse_port(source : BytesView, authority : Authority) -> BytesView {
  match source {
    [':', .. k] => {
      let mut port_val = 0
      for s = k {
        match s {
          [d, .. s] if is_digit_byte(d) => {
            port_val = port_val * 10 + (d.to_int() - '0')
            continue s
          }
          _ as s => {
            authority.port = Some(port_val)
            return s
          }
        }
      }
    }
    _ => source
  }
}

///|
fn parse_authority(source : BytesView, uri : Uri) -> BytesView raise ParseError {
  let authority = Authority::{ userinfo: None, host: RegName(""), port: None }
  uri.authority = Some(authority)

  // Try to parse userinfo first
  let remaining = parse_userinfo(source, authority) catch {
    _ => source // No userinfo, continue with host
  }
  let remaining = parse_host(remaining, authority)
  parse_port(remaining, authority)
}

///|
fn parse_segment(source : BytesView) -> (BytesView, BytesView) raise ParseError {
  let start = source
  for s = source {
    match s {
      ['%', .. k] => continue parse_percent_encoding(k)
      [b, .. k] if is_pchar_byte(b) => continue k
      _ as s => return (s, start.slice_until(s))
    }
  }
}

///|
/// Continuation-based completion functions
fn parse_done(source : BytesView, _uri : Uri) -> BytesView {
  source
}

///|
fn parse_fragment(source : BytesView, uri : Uri) -> BytesView raise ParseError {
  for s = source {
    match s {
      ['%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_pchar_byte(b) || b == '/' || b == '?' => continue k
      [..] as s => {
        uri.fragment = Some(source.slice_until(s))
        return s
      }
    }
  }
}

///|
fn parse_query_then_fragment(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let start = source
  for s = source {
    match s {
      ['#', .. k] as s => {
        uri.query = Some(start.slice_until(s))
        return parse_fragment(k, uri)
      }
      ['%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_pchar_byte(b) || b == '/' || b == '?' => continue k
      [..] as s => {
        uri.query = Some(start.slice_until(s))
        return s
      }
    }
  }
}

///|
fn parse_path_abempty_then_query(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  for s = source {
    match s {
      ['%', .. k] => continue parse_percent_encoding(k)
      ['/', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != "" {
          uri.path.push(segment)
        }
        return parse_path_abempty_then_query(k, uri)
      }
      ['?', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != "" {
          uri.path.push(segment)
        }
        return parse_query_then_fragment(k, uri)
      }
      ['#', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != "" {
          uri.path.push(segment)
        }
        return parse_fragment(k, uri)
      }
      [b, .. k] if is_pchar_byte(b) => continue k
      [] as s => {
        let segment = source.slice_until(s)
        if segment != "" {
          uri.path.push(segment)
        }
        return s
      }
      [..] as s => raise InvalidSegment(s)
    }
  }
}

///|
fn parse_hier_part_then_query(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. "//", .. k] =>
      match parse_authority(k, uri) {
        ['/', .. k] => parse_path_abempty_then_query(k, uri)
        ['?', .. k] => parse_query_then_fragment(k, uri)
        ['#', ..] => parse_fragment(k, uri)
        [] => parse_done(k, uri)
        [..] as s => raise Invalid(s)
      }
    _ => parse_path_abempty_then_query(source, uri)
  }
}

///|
fn parse_absolute_uri(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let remaining = parse_scheme(source, uri) // already consumes the ':'
  parse_hier_part_then_query_no_fragment(remaining, uri)
}

///|
fn parse_hier_part_then_query_no_fragment(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. "//", .. k] => {
      let remaining = parse_authority(k, uri)
      parse_path_abempty_then_query_no_fragment(remaining, uri)
    }
    _ => parse_path_abempty_then_query_no_fragment(source, uri)
  }
}

///|
fn parse_path_abempty_then_query_no_fragment(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  for s = source {
    match s {
      ['/', .. k] => {
        let (remaining, segment_val) = parse_segment(k)
        if segment_val != "" {
          uri.path.push(segment_val)
        }
        continue remaining
      }
      _ as s => return parse_query_no_fragment_or_done(s, uri)
    }
  }
}

///|
fn parse_query_no_fragment_or_done(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    ['?', .. k] => parse_query_no_fragment_then_done(k, uri)
    _ => parse_done(source, uri)
  }
}

///|
fn parse_query_no_fragment_then_done(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let start = source
  for s = source {
    match s {
      ['%', .. k] => continue parse_percent_encoding(k)
      [b, .. k] if is_pchar_byte(b) || b == '/' || b == '?' => continue k
      _ as s => {
        uri.query = Some(start.slice_until(s))
        return parse_done(s, uri)
      }
    }
  }
}

///|
fn remove_dot_segments(path : Array[BytesView]) -> Array[BytesView] {
  let output = Array::new()
  for segment in path {
    if segment == "." {
      continue // Remove single dot segments
    } else if segment == ".." {
      if output.length() > 0 {
        output.pop() |> ignore() // Remove last segment and the .. segment
      }
      // If output is empty, ignore the .. segment
    } else {
      output.push(segment)
    }
  }
  output
}

///|
test "RFC 3986 URI Reference Parsing" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(
    parse_uri_reference(
      "http://example.com/path/to/resource?query=parameter#fragment", uri,
    ),
    "",
  )
  assert_eq(uri.scheme, Some("http"))
  assert_eq(
    uri.authority,
    Some({ userinfo: None, host: RegName("example.com"), port: None }),
  )
  assert_eq(uri.path, ["path", "to", "resource"])
  assert_eq(uri.query, Some("query=parameter"))
  assert_eq(uri.fragment, Some("fragment"))
}

///|
test "RFC 3986 Authority with Userinfo and Port" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(
    parse_uri_reference("ftp://user:pass@ftp.example.com:21/path", uri),
    "",
  )
  assert_eq(uri.scheme, Some("ftp"))
  assert_eq(
    uri.authority,
    Some({
      userinfo: Some("user:pass"),
      host: RegName("ftp.example.com"),
      port: Some(21),
    }),
  )
  assert_eq(uri.path, ["path"])
}

///|
test "RFC 3986 IPv6 Literal" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("http://[2001:db8::1]:8080/", uri), "")
  assert_eq(uri.scheme, Some("http"))
  assert_eq(
    uri.authority,
    Some({ userinfo: None, host: IPv6Address("2001:db8::1"), port: Some(8080) }),
  )
  assert_eq(uri.path, [])
}

///|
test "RFC 3986 Percent Encoding Preservation" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("http://example.com/hello%20world", uri), "")
  assert_eq(uri.scheme, Some("http"))
  assert_eq(uri.path, ["hello%20world"]) // preserved, not decoded
}

///|
test "RFC 3986 Relative Reference" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("../path/file.txt", uri), "")
  assert_eq(uri.scheme, None)
  assert_eq(uri.authority, None)
  assert_eq(uri.path, ["..", "path", "file.txt"])
}

///|
test "RFC 3986 Absolute Path" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("/absolute/path", uri), "")
  assert_eq(uri.scheme, None)
  assert_eq(uri.authority, None)
  assert_eq(uri.path, ["absolute", "path"])
}

///|
test "RFC 3986 Query Only" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("?key=value&foo=bar", uri), "")
  assert_eq(uri.scheme, None)
  assert_eq(uri.authority, None)
  assert_eq(uri.path, [])
  assert_eq(uri.query, Some("key=value&foo=bar"))
}

///|
test "RFC 3986 Fragment Only" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(parse_uri_reference("#section1", uri), "")
  assert_eq(uri.scheme, None)
  assert_eq(uri.authority, None)
  assert_eq(uri.path, [])
  assert_eq(uri.fragment, Some("section1"))
}

///|
test "RFC 3986 Character Classification" {
  // Test unreserved characters
  assert_eq(is_unreserved_byte('A'), true)
  assert_eq(is_unreserved_byte('z'), true)
  assert_eq(is_unreserved_byte('0'), true)
  assert_eq(is_unreserved_byte('-'), true)
  assert_eq(is_unreserved_byte('.'), true)
  assert_eq(is_unreserved_byte('_'), true)
  assert_eq(is_unreserved_byte('~'), true)
  assert_eq(is_unreserved_byte('!'), false)

  // Test gen-delims
  assert_eq(is_gen_delim_byte(':'), true)
  assert_eq(is_gen_delim_byte('/'), true)
  assert_eq(is_gen_delim_byte('?'), true)
  assert_eq(is_gen_delim_byte('#'), true)
  assert_eq(is_gen_delim_byte('['), true)
  assert_eq(is_gen_delim_byte(']'), true)
  assert_eq(is_gen_delim_byte('@'), true)

  // Test sub-delims
  assert_eq(is_sub_delim_byte('!'), true)
  assert_eq(is_sub_delim_byte('$'), true)
  assert_eq(is_sub_delim_byte('&'), true)
  assert_eq(is_sub_delim_byte('\''), true)
  assert_eq(is_sub_delim_byte('('), true)
  assert_eq(is_sub_delim_byte(')'), true)
  assert_eq(is_sub_delim_byte('*'), true)
  assert_eq(is_sub_delim_byte('+'), true)
  assert_eq(is_sub_delim_byte(','), true)
  assert_eq(is_sub_delim_byte(';'), true)
  assert_eq(is_sub_delim_byte('='), true)
}

///|
test "RFC 3986 Dot Segment Removal" {
  let path1 : Array[BytesView] = ["a", "b", "c", ".", "..", "..", "g"]
  let result1 = remove_dot_segments(path1)
  assert_eq(result1, ["a", "g"])
  let path2 : Array[BytesView] = ["..", "..", "a", "b"]
  let result2 = remove_dot_segments(path2)
  assert_eq(result2, ["a", "b"])
  let path3 : Array[BytesView] = [".", "a", ".", "b", "."]
  let result3 = remove_dot_segments(path3)
  assert_eq(result3, ["a", "b"])
}

///|
test "parse_percent_encoding accepts only hex digits" {
  // Valid hex digits
  let ok1 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "20 rest",
  )
  assert_true(ok1 is Ok(_))
  let ok2 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "FF end",
  )
  assert_true(ok2 is Ok(_))
  let ok3 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "ab end",
  )
  assert_true(ok3 is Ok(_))
  // Invalid: non-hex letters
  let bad1 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "GG end",
  )
  assert_true(bad1 is Err(_))
  let bad2 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "xz end",
  )
  assert_true(bad2 is Err(_))
  let bad3 : Result[BytesView, ParseError] = try? parse_percent_encoding(
    "ZZ end",
  )
  assert_true(bad3 is Err(_))
}

///|
test "parse rejects URI with invalid percent encoding" {
  let bad : Result[Uri, ParseError] = try? Uri::parse(
    "http://example.com/path%GG",
  )
  assert_true(bad is Err(_))
}

///|
test "RFC 3986 Absolute URI Parsing" {
  let uri = Uri::{
    scheme: None,
    authority: None,
    path: [],
    query: None,
    fragment: None,
  }
  assert_eq(
    parse_absolute_uri(
      "http://example.com/path/to/resource?query=parameter", uri,
    ),
    "",
  )
  assert_eq(uri.scheme, Some("http"))
  assert_eq(
    uri.authority,
    Some({ userinfo: None, host: RegName("example.com"), port: None }),
  )
  assert_eq(uri.path, ["path", "to", "resource"])
  assert_eq(uri.query, Some("query=parameter"))
  assert_eq(uri.fragment, None)
}
