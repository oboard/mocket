///|
pub suberror MultipartError {
  MultipartError(String)
} derive(Debug)

///|
/// A sequential, streaming MIME multipart reader (RFC 2046 section 5.1.1).
/// The source must be limited to the enclosing message body.
struct Reader {
  input : ReaderState
  /// Whether the first boundary has been read.
  mut started : Bool
  /// Last returned part. `next_part` reads and discards any remaining body.
  mut current : PartReader?
}

///|
/// `boundary` is the decoded Content-Type parameter, without quotes or `--`.
pub fn Reader::Reader(
  source : &@io.Reader,
  boundary~ : String,
) -> Self raise MultipartError {
  validate_boundary(boundary)
  {
    input: {
      source,
      delimiter: @utf8.encode("\r\n--\{boundary}"),
      // Treat the start of the message as a line start when scanning the preamble.
      pending: b"\r\n",
      cursor: 0,
      ready: 0,
      eof: false,
      finished: false,
    },
    started: false,
    current: None,
  }
}

///|
/// Read the next part's headers and a reader limited to its body. Advancing
/// drains the previous part; retained readers then return EOF. Preamble and
/// epilogue are ignored. Bodies are returned without transfer decoding.
/// Header folding is unfolded; repeated names are comma-joined as in @http.Headers.
/// Calls on this reader and its current part must be made sequentially.
// async@0.21.3 requires ReaderBuffer to implement io.Reader, but marks its
// constructor internal. No public adapter supports this pull-based part reader.
#warnings("-alert_internal")
pub async fn Reader::next_part(self : Self) -> (@http.Headers, &@io.Reader)? {
  if self.current is Some(part) {
    while @io.Reader::read_some(part) is Some(_) {
      ()
    }
    self.current = None
  } else if !self.started {
    while self.input.scan_body() {
      self.input.cursor += self.input.ready
      self.input.ready = 0
    }
    self.started = true
  }
  if self.input.finished {
    return None
  }
  let headers = self.input.read_headers()
  let part = PartReader::{
    input: self.input,
    buffer: @io.ReaderBuffer::new(),
    at_start: true,
    done: false,
  }
  self.current = Some(part)
  Some((headers, part))
}

///|
// Required by io.Reader::_get_internal_buffer in async@0.21.3.
#warnings("-alert_internal")
priv struct PartReader {
  input : ReaderState
  buffer : @io.ReaderBuffer
  mut at_start : Bool
  mut done : Bool
}

///|
impl @io.Reader for PartReader with fn _get_internal_buffer(self) {
  self.buffer
}

///|
impl @io.Reader for PartReader with fn _direct_read(
  self,
  dst,
  offset~,
  max_len~,
) {
  if self.done || max_len == 0 {
    return 0
  }
  if self.at_start {
    self.at_start = false
    // RFC 2046 permits a body-part containing only MIME headers. Its boundary's
    // CRLF was consumed as the blank header line, so match without it here.
    let length = self.input.delimiter.length() - 2
    let boundary = for i = 0; i < length; i = i + 1 {
      guard self.input.ensure(i + 1) else {
        raise MultipartError("Unexpected EOF before multipart boundary")
      }
      if self.input.pending[self.input.cursor + i] !=
        self.input.delimiter[i + 2] {
        break false
      }
    } nobreak {
      true
    }
    if boundary && self.input.consume_boundary(length) {
      self.done = true
      return 0
    }
  }
  if !self.input.scan_body() {
    self.done = true
    return 0
  }
  let count = @cmp.minimum(self.input.ready, max_len)
  dst.blit_from_bytes(offset, self.input.pending, self.input.cursor, count)
  self.input.cursor += count
  self.input.ready -= count
  count
}
