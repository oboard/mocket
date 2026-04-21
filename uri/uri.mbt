// URI parser implementation following RFC 3986

///|
pub enum Host {
  IPv6Address(BytesView)
  RegName(BytesView)
} derive(Eq, Debug)

///|
pub struct Authority {
  mut userinfo : BytesView?
  mut host : Host
  mut port : Int?
} derive(Eq, Debug)

///|
pub struct Uri {
  mut scheme : BytesView?
  mut authority : Authority?
  path : Array[BytesView]
  mut query : BytesView?
  mut fragment : BytesView?
} derive(Eq, Debug)

///|
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
  (b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z')
}

///|
fn is_digit_byte(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
fn is_hexdig_byte(b : Byte) -> Bool {
  is_digit_byte(b) || (b >= b'A' && b <= b'F') || (b >= b'a' && b <= b'f')
}

///|
fn is_unreserved_byte(b : Byte) -> Bool {
  is_alpha_byte(b) ||
  is_digit_byte(b) ||
  b == b'-' ||
  b == b'.' ||
  b == b'_' ||
  b == b'~'
}

///|
fn is_gen_delim_byte(b : Byte) -> Bool {
  b == b':' ||
  b == b'/' ||
  b == b'?' ||
  b == b'#' ||
  b == b'[' ||
  b == b']' ||
  b == b'@'
}

///|
fn is_sub_delim_byte(b : Byte) -> Bool {
  b == b'!' ||
  b == b'$' ||
  b == b'&' ||
  b == b'\'' ||
  b == b'(' ||
  b == b')' ||
  b == b'*' ||
  b == b'+' ||
  b == b',' ||
  b == b';' ||
  b == b'='
}

///|
fn is_pchar_byte(b : Byte) -> Bool {
  is_unreserved_byte(b) || is_sub_delim_byte(b) || b == b':' || b == b'@'
}

// RFC 3986 Parsing Functions

// URI-reference = scheme b":" b"//" authority path-abempty [ b"?" query ] [ b"#" fragment ]
//               / scheme b":" b"/" [ segment-nz *( b"/" segment ) ] [ b"?" query ] [ b"#" fragment ]
//               / scheme b":" segment-nz *( b"/" segment ) [ b"?" query ] [ b"#" fragment ]
//               / scheme b":" [ b"?" query ] [ b"#" fragment ]
//               / b"//" authority path-abempty [ b"?" query ] [ b"#" fragment ]
//               / b"/" [ segment-nz *( b"/" segment ) ] [ b"?" query ] [ b"#" fragment ]
//               / segment-nz-nc *( b"/" segment ) [ b"?" query ] [ b"#" fragment ]
//               / [ b"?" query ] [ b"#" fragment ]

///|
fn parse_scheme_or_segment_nz_nc(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let segment = source
  for s = source {
    match s {
      [b':', .. k] as s => {
        uri.scheme = Some(source.slice_until(s))
        return parse_hier_part_then_query(k, uri)
      }
      [b'/', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_path_abempty_then_query(k, uri)
      }
      [b'?', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_query_then_fragment(k, uri)
      }
      [b'#', .. k] as s => {
        uri.path.push(segment.slice_until(s))
        return parse_query_then_fragment(k, uri)
      }
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) || b == b'@' =>
        continue k
      _ => raise ParseError::InvalidSchemeOrSegment(source)
    }
  }
}

///|
fn parse_uri_reference(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. b"//", .. k] => {
      // relative-ref > relative-part > b"//" authority path-abempty
      let k = parse_authority(k, uri)
      parse_path_abempty_then_query(k, uri)
    }
    [b'/', .. k] =>
      // relative-ref > relative-part > b"/" [ segment-nz *( b"/" segment ) ] [ b"?" query ] [ b"#" fragment ]
      parse_path_abempty_then_query(k, uri)
    [b'?', .. k] =>
      // relative-ref > relative-part > b"?" query
      parse_query_then_fragment(k, uri)
    [b'#', .. k] =>
      // relative-ref > relative-part > b"#" fragment
      parse_fragment(k, uri)
    [..] as s => parse_scheme_or_segment_nz_nc(s, uri)
  }
}

///|
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
    raise ParseError::Invalid(source)
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
            b == b'+' ||
            b == b'-' ||
            b == b'.' => continue s
          [b':', .. k] as s => {
            uri.scheme = Some(source.slice_until(s))
            return k
          }
          [_, ..] as s => raise ParseError::InvalidScheme(s)
          [] => raise ParseError::MissingColon
        }
      }
    [_, ..] as s => raise ParseError::InvalidScheme(s)
    [] => raise ParseError::MissingScheme
  }
}

///|
fn parse_percent_encoding(source : BytesView) -> BytesView raise ParseError {
  match source {
    [
      b'0'..=b'9'
      | b'A'..=b'Z'
      | b'a'..=b'z',
      b'0'..=b'9'
      | b'A'..=b'Z'
      | b'a'..=b'z',
      .. source,
    ] => source
    [..] => raise ParseError::InvalidPercentEncoding(source)
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
      [b'@', .. k] as s => {
        authority.userinfo = Some(start.slice_until(s))
        return k
      }
      [b'%', .. k] => continue parse_percent_encoding(k)
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) || b == b':' =>
        continue k
      [_, ..] as s => raise ParseError::InvalidHeirPart(s)
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
      [b'%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_unreserved_byte(b) || is_sub_delim_byte(b) => continue k
      _ as s => {
        authority.host = Host::RegName(source.slice_until(s))
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
  // Simplified IPv6 parsing - match until b']'
  for s = source {
    match s {
      [b']', .. k] as s => {
        authority.host = IPv6Address(source.slice_until(s))
        return k
      }
      [b, .. s] if is_hexdig_byte(b) || b == b':' || b == b'.' => continue s
      _ as s => raise ParseError::InvalidHeirPart(s)
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
    [b'[', .. k] => parse_ipv6_address(k, authority)
    _ =>
      // Try IPv4 address, fallback to reg-name
      parse_reg_name(source, authority)
  }
}

///|
fn parse_port(source : BytesView, authority : Authority) -> BytesView {
  match source {
    [b':', .. k] => {
      let mut port_val = 0
      for s = k {
        match s {
          [d, .. s] if is_digit_byte(d) => {
            port_val = port_val * 10 + (d.to_int() - b'0'.to_int())
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
  let authority = Authority::{ userinfo: None, host: RegName(b""), port: None }
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
      [b'%', .. k] => continue parse_percent_encoding(k)
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
      [b'%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_pchar_byte(b) || b == b'/' || b == b'?' => continue k
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
      [b'#', .. k] as s => {
        uri.query = Some(start.slice_until(s))
        return parse_fragment(k, uri)
      }
      [b'%', ..] as s => continue parse_percent_encoding(s)
      [b, .. k] if is_pchar_byte(b) || b == b'/' || b == b'?' => continue k
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
      [b'%', .. k] => continue parse_percent_encoding(k)
      [b'/', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != b"" {
          uri.path.push(segment)
        }
        return parse_path_abempty_then_query(k, uri)
      }
      [b'?', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != b"" {
          uri.path.push(segment)
        }
        return parse_query_then_fragment(k, uri)
      }
      [b'#', .. k] as s => {
        let segment = source.slice_until(s)
        if segment != b"" {
          uri.path.push(segment)
        }
        return parse_fragment(k, uri)
      }
      [b, .. k] if is_pchar_byte(b) => continue k
      [] as s => {
        let segment = source.slice_until(s)
        if segment != b"" {
          uri.path.push(segment)
        }
        return s
      }
      [..] as s => raise ParseError::InvalidSegment(s)
    }
  }
}

///|
fn parse_hier_part_then_query(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. b"//", .. k] =>
      match parse_authority(k, uri) {
        [b'/', .. k] => parse_path_abempty_then_query(k, uri)
        [b'?', .. k] => parse_query_then_fragment(k, uri)
        [b'#', ..] => parse_fragment(k, uri)
        [] => parse_done(k, uri)
        [..] as s => raise ParseError::Invalid(s)
      }
    _ => parse_path_abempty_then_query(source, uri)
  }
}

///|
fn parse_absolute_uri(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  let remaining = parse_scheme(source, uri) // already consumes the b':'
  parse_hier_part_then_query_no_fragment(remaining, uri)
}

///|
fn parse_hier_part_then_query_no_fragment(
  source : BytesView,
  uri : Uri,
) -> BytesView raise ParseError {
  match source {
    [.. b"//", .. k] => {
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
      [b'/', .. k] => {
        let (remaining, segment_val) = parse_segment(k)
        if segment_val != b"" {
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
    [b'?', .. k] => parse_query_no_fragment_then_done(k, uri)
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
      [b'%', .. k] => continue parse_percent_encoding(k)
      [b, .. k] if is_pchar_byte(b) || b == b'/' || b == b'?' => continue k
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
    if segment == b"." {
      continue // Remove single dot segments
    } else if segment == b".." {
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
      b"http://example.com/path/to/resource?query=parameter#fragment", uri,
    ),
    b"",
  )
  assert_eq(uri.scheme, Some(b"http"))
  assert_true(
    uri.authority ==
    Some(Authority::{
      userinfo: None,
      host: RegName(b"example.com"),
      port: None,
    }),
  )
  assert_eq(uri.path, [b"path", b"to", b"resource"])
  assert_eq(uri.query, Some(b"query=parameter"))
  assert_eq(uri.fragment, Some(b"fragment"))
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
    parse_uri_reference(b"ftp://user:pass@ftp.example.com:21/path", uri),
    b"",
  )
  assert_eq(uri.scheme, Some(b"ftp"))
  assert_true(
    uri.authority ==
    Some(Authority::{
      userinfo: Some(b"user:pass"),
      host: RegName(b"ftp.example.com"),
      port: Some(21),
    }),
  )
  assert_eq(uri.path, [b"path"])
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
  assert_eq(parse_uri_reference(b"http://[2001:db8::1]:8080/", uri), b"")
  assert_eq(uri.scheme, Some(b"http"))
  assert_true(
    uri.authority ==
    Some(Authority::{
      userinfo: None,
      host: IPv6Address(b"2001:db8::1"),
      port: Some(8080),
    }),
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
  assert_eq(parse_uri_reference(b"http://example.com/hello%20world", uri), b"")
  assert_eq(uri.scheme, Some(b"http"))
  assert_eq(uri.path, [b"hello%20world"]) // preserved, not decoded
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
  assert_eq(parse_uri_reference(b"../path/file.txt", uri), b"")
  assert_eq(uri.scheme, None)
  assert_true(uri.authority == None)
  assert_eq(uri.path, [b"..", b"path", b"file.txt"])
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
  assert_eq(parse_uri_reference(b"/absolute/path", uri), b"")
  assert_eq(uri.scheme, None)
  assert_true(uri.authority == None)
  assert_eq(uri.path, [b"absolute", b"path"])
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
  assert_eq(parse_uri_reference(b"?key=value&foo=bar", uri), b"")
  assert_eq(uri.scheme, None)
  assert_true(uri.authority == None)
  assert_eq(uri.path, [])
  assert_eq(uri.query, Some(b"key=value&foo=bar"))
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
  assert_eq(parse_uri_reference(b"#section1", uri), b"")
  assert_eq(uri.scheme, None)
  assert_true(uri.authority == None)
  assert_eq(uri.path, [])
  assert_eq(uri.fragment, Some(b"section1"))
}

///|
test "RFC 3986 Character Classification" {
  // Test unreserved characters
  assert_eq(is_unreserved_byte(b'A'), true)
  assert_eq(is_unreserved_byte(b'z'), true)
  assert_eq(is_unreserved_byte(b'0'), true)
  assert_eq(is_unreserved_byte(b'-'), true)
  assert_eq(is_unreserved_byte(b'.'), true)
  assert_eq(is_unreserved_byte(b'_'), true)
  assert_eq(is_unreserved_byte(b'~'), true)
  assert_eq(is_unreserved_byte(b'!'), false)

  // Test gen-delims
  assert_eq(is_gen_delim_byte(b':'), true)
  assert_eq(is_gen_delim_byte(b'/'), true)
  assert_eq(is_gen_delim_byte(b'?'), true)
  assert_eq(is_gen_delim_byte(b'#'), true)
  assert_eq(is_gen_delim_byte(b'['), true)
  assert_eq(is_gen_delim_byte(b']'), true)
  assert_eq(is_gen_delim_byte(b'@'), true)

  // Test sub-delims
  assert_eq(is_sub_delim_byte(b'!'), true)
  assert_eq(is_sub_delim_byte(b'$'), true)
  assert_eq(is_sub_delim_byte(b'&'), true)
  assert_eq(is_sub_delim_byte(b'\''), true)
  assert_eq(is_sub_delim_byte(b'('), true)
  assert_eq(is_sub_delim_byte(b')'), true)
  assert_eq(is_sub_delim_byte(b'*'), true)
  assert_eq(is_sub_delim_byte(b'+'), true)
  assert_eq(is_sub_delim_byte(b','), true)
  assert_eq(is_sub_delim_byte(b';'), true)
  assert_eq(is_sub_delim_byte(b'='), true)
}

///|
test "RFC 3986 Dot Segment Removal" {
  let path1 : Array[BytesView] = [b"a", b"b", b"c", b".", b"..", b"..", b"g"]
  let result1 = remove_dot_segments(path1)
  assert_eq(result1, [b"a", b"g"])
  let path2 : Array[BytesView] = [b"..", b"..", b"a", b"b"]
  let result2 = remove_dot_segments(path2)
  assert_eq(result2, [b"a", b"b"])
  let path3 : Array[BytesView] = [b".", b"a", b".", b"b", b"."]
  let result3 = remove_dot_segments(path3)
  assert_eq(result3, [b"a", b"b"])
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
      b"http://example.com/path/to/resource?query=parameter", uri,
    ),
    b"",
  )
  assert_eq(uri.scheme, Some(b"http"))
  assert_true(
    uri.authority ==
    Some(Authority::{
      userinfo: None,
      host: RegName(b"example.com"),
      port: None,
    }),
  )
  assert_eq(uri.path, [b"path", b"to", b"resource"])
  assert_eq(uri.query, Some(b"query=parameter"))
  assert_eq(uri.fragment, None)
}
