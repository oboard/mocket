// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
#cfg(platform="windows")
#external
priv type Schannel

///|
#cfg(platform="windows")
extern "C" fn Schannel::new() -> Schannel = "moonbitlang_async_schannel_new"

///|
#cfg(platform="windows")
extern "C" fn Schannel::free(ch : Schannel) = "moonbitlang_async_schannel_free"

///|
#cfg(platform="windows")
extern "C" fn Schannel::init_client(ch : Schannel, verify~ : Bool) -> Int = "moonbitlang_async_schannel_init_client"

///|
#cfg(platform="windows")
extern "C" fn Schannel::init_server(ch : Schannel) -> Int = "moonbitlang_async_schannel_init_server"

///|
#cfg(platform="windows")
extern "C" fn Schannel::bytes_read(ch : Schannel) -> Int = "moonbitlang_async_schannel_bytes_read"

///|
#cfg(platform="windows")
extern "C" fn Schannel::bytes_to_write(ch : Schannel) -> Int = "moonbitlang_async_schannel_bytes_to_write"

///|
#cfg(platform="windows")
extern "C" fn Schannel::header_size(ch : Schannel) -> Int = "moonbitlang_async_schannel_header_size"

///|
#cfg(platform="windows")
extern "C" fn Schannel::trailer_size(ch : Schannel) -> Int = "moonbitlang_async_schannel_trailer_size"

///|
#cfg(platform="windows")
fn Schannel::record_overhead(ch : Schannel) -> Int {
  ch.header_size() + ch.trailer_size()
}

///|
#cfg(platform="windows")
priv enum TlsState {
  Completed = 0
  WantRead = 1
  WantWrite = 2
  Error = 3
  Eof = 4
  ReNegotiation = 5
}

///|
#cfg(platform="windows")
#borrow(ch, host, in_buffer, out_buffer)
extern "C" fn Schannel::connect(
  ch : Schannel,
  host : @os_string.OsString?,
  in_buffer~ : Bytes,
  in_buffer_offset~ : Int,
  in_buffer_len~ : Int,
  out_buffer~ : FixedArray[Byte],
  out_buffer_offset~ : Int,
  out_buffer_len~ : Int,
) -> TlsState = "moonbitlang_async_schannel_connect"

///|
#cfg(platform="windows")
#borrow(ch, in_buffer, out_buffer)
extern "C" fn Schannel::accept(
  ch : Schannel,
  in_buffer~ : Bytes,
  in_buffer_offset~ : Int,
  in_buffer_len~ : Int,
  out_buffer~ : FixedArray[Byte],
  out_buffer_offset~ : Int,
  out_buffer_len~ : Int,
) -> TlsState = "moonbitlang_async_schannel_accept"

///|
#cfg(platform="windows")
struct Tls {
  context : Schannel
  is_client : Bool
  host : String?
  read_buf : @io.ReaderBuffer
  transport : Transport
  mut curr_msg_remaining : Int
  mut curr_msg_trailer : Int
  mut shutdown : Bool
  mut closed : Bool
}

///|
/// Close a TLS connection and release related resource.
/// THIS FUNCTION MUST BE CALLED BEFORE CLOSING UNDERLYING TRANSPORT!!!
///
/// Note that this function will not perform the TLS shutdown process,
/// for graceful shutdown of a TLS connection, see `TLS::shutdown`.
#cfg(platform="windows")
pub fn Tls::close(self : Tls) -> Unit {
  guard !self.closed else {  }
  self.closed = true
  if self.transport.state is Normal {
    self.transport.state = Closed
  }
  self.context.free()
}

///|
#cfg(platform="windows")
async fn Tls::connect(self : Tls) -> Unit {
  let host = match self.host {
    None => None
    Some(str) => Some(@os_string.encode(str))
  }
  let read_buf = self.transport.reader._get_internal_buffer().repr()
  let write_buf = self.transport.write_buf
  for ;; {
    let ret = self.context.connect(
      host,
      in_buffer=read_buf.buf.unsafe_reinterpret_as_bytes(),
      in_buffer_offset=read_buf.start,
      in_buffer_len=read_buf.len,
      out_buffer=write_buf.buf,
      out_buffer_offset=write_buf.start,
      out_buffer_len=write_buf.buf.length() - write_buf.start - write_buf.len,
    )
    read_buf.drop(self.context.bytes_read())
    write_buf.len += self.context.bytes_to_write()
    match ret {
      Completed | Eof => {
        self.transport.flush_write()
        break
      }
      WantRead => self.transport.read_more()
      WantWrite => self.transport.flush_write()
      Error => {
        let errno = @os_error.get_errno()
        raise TlsError(@os_error.errno_to_string(errno))
      }
      ReNegotiation => panic()
    }
  }
}

///|
#cfg(platform="windows")
pub async fn[R : @io.Reader, W : @io.Writer] Tls::client_from_pair(
  reader : R,
  writer : W,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
) -> Tls {
  ignore(sni)
  let context = Schannel::new()
  if context.init_client(verify~) is err && err != 0 {
    context.free()
    raise TlsError(@os_error.errno_to_string(err))
  }
  let transport = Transport::new(reader, writer)
  let tls = {
    context,
    is_client: true,
    host,
    read_buf: @io.ReaderBuffer::new(),
    curr_msg_remaining: 0,
    curr_msg_trailer: 0,
    transport,
    shutdown: false,
    closed: false,
  }
  tls.connect() catch {
    err => {
      tls.close()
      raise err
    }
  }
  tls
}

///|
#cfg(platform="windows")
async fn Tls::accept(self : Tls) -> Unit {
  let read_buf = self.transport.reader._get_internal_buffer().repr()
  let write_buf = self.transport.write_buf
  for ;; {
    let ret = self.context.accept(
      in_buffer=read_buf.buf.unsafe_reinterpret_as_bytes(),
      in_buffer_offset=read_buf.start,
      in_buffer_len=read_buf.len,
      out_buffer=write_buf.buf,
      out_buffer_offset=write_buf.start + write_buf.len,
      out_buffer_len=write_buf.buf.length() - write_buf.start - write_buf.len,
    )
    read_buf.drop(self.context.bytes_read())
    write_buf.len += self.context.bytes_to_write()
    match ret {
      Completed | Eof => {
        self.transport.flush_write()
        break
      }
      WantRead => self.transport.read_more()
      WantWrite => self.transport.flush_write()
      Error => {
        let errno = @os_error.get_errno()
        raise TlsError(@os_error.errno_to_string(errno))
      }
      ReNegotiation => panic()
    }
  }
}

///|
#internal(internal, "do not use, for internal testing only")
#cfg(platform="windows")
pub async fn[R : @io.Reader, W : @io.Writer] Tls::server_from_pair(
  reader : R,
  writer : W,
) -> Tls {
  let context = Schannel::new()
  if context.init_server() is err && err != 0 {
    context.free()
    raise TlsError(@os_error.errno_to_string(err))
  }
  let transport = Transport::new(reader, writer)
  let tls = {
    context,
    is_client: false,
    host: None,
    read_buf: @io.ReaderBuffer::new(),
    transport,
    curr_msg_remaining: 0,
    curr_msg_trailer: 0,
    shutdown: false,
    closed: false,
  }
  tls.accept() catch {
    err => {
      tls.close()
      raise err
    }
  }
  tls
}

///|
#cfg(platform="windows")
pub impl @io.Reader for Tls with _get_internal_buffer(self) {
  self.read_buf
}

///|
#cfg(platform="windows")
#borrow(self, buf)
extern "C" fn Schannel::read(
  self : Schannel,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
) -> TlsState = "moonbitlang_async_schannel_read"

///|
#cfg(platform="windows")
extern "C" fn Schannel::msg_trailer(ch : Schannel) -> Int = "moonbitlang_async_schannel_msg_trailer"

///|
#cfg(platform="windows")
pub impl @io.Reader for Tls with _direct_read(self, buf, offset~, max_len~) {
  if self.closed {
    return 0
  }
  let read_buf = self.transport.reader._get_internal_buffer().repr()
  while self.curr_msg_remaining == 0 {
    read_buf.enlarge_to(self.context.record_overhead() + 1)
    let ret = self.context.read(
      read_buf.buf,
      offset=read_buf.start,
      len=read_buf.len,
    )
    match ret {
      Completed => {
        let msg_size = self.context.bytes_read()
        read_buf.drop(self.context.header_size())
        self.curr_msg_trailer = self.context.msg_trailer()
        self.curr_msg_remaining = msg_size -
          self.context.header_size() -
          self.curr_msg_trailer
      }
      WantRead if read_buf.len == 0 && self.transport.state is Closed =>
        return 0
      WantRead => self.transport.read_more()
      Eof => {
        self.shutdown()
        return 0
      }
      WantWrite => panic()
      Error => {
        let errno = @os_error.get_errno()
        raise TlsError(@os_error.errno_to_string(errno))
      }
      ReNegotiation =>
        if self.is_client {
          self.connect()
        } else {
          self.accept()
        }
    }
  }

  // check if there is remaining data
  let len = @cmp.minimum(self.curr_msg_remaining, max_len)
  read_buf.buf.blit_to(buf, len~, src_offset=read_buf.start, dst_offset=offset)
  read_buf.drop(len)
  self.curr_msg_remaining -= len
  if self.curr_msg_remaining == 0 {
    read_buf.drop(self.curr_msg_trailer)
  }
  len
}

///|
#cfg(platform="windows")
#borrow(self, buf)
extern "C" fn Schannel::write(
  self : Schannel,
  buf : FixedArray[Byte],
  offset~ : Int, // `offset` marks the start of the whole message
  len~ : Int, // `len` is the length of payload
) -> TlsState = "moonbitlang_async_schannel_write"

///|
#cfg(platform="windows")
pub impl @io.Writer for Tls with write_once(self, buf, offset~, len~) {
  let write_buf = self.transport.write_buf
  guard write_buf.len == 0
  let max_len = write_buf.buf.length() -
    write_buf.start -
    self.context.record_overhead()
  let len = @cmp.minimum(len, max_len)
  write_buf.buf.blit_from_bytes(
    write_buf.start + self.context.header_size(), // dst offset
    buf, // dst
    offset, // src offset
    len, // length
  )
  let ret = self.context.write(write_buf.buf, offset=write_buf.start, len~)
  write_buf.len += self.context.bytes_to_write()
  if ret is WantWrite {
    self.transport.flush_write()
    len
  } else {
    let errno = @os_error.get_errno()
    raise TlsError(@os_error.errno_to_string(errno))
  }
}

///|
#cfg(platform="windows")
#borrow(ch)
extern "C" fn Schannel::shutdown(ch : Schannel) -> Int = "moonbitlang_async_schannel_shutdown"

///|
#cfg(platform="windows")
pub async fn Tls::shutdown(self : Tls) -> Unit {
  guard !self.shutdown else {  }
  self.shutdown = true
  match self.transport.state {
    Normal => ()
    Closed => return
    Error(err) => raise err
  }
  if self.context.shutdown() is err && err != 0 {
    raise TlsError(@os_error.errno_to_string(err))
  }
  if self.is_client {
    self.connect()
  } else {
    self.accept()
  }
}

///|
// mute unused warning
#cfg(platform="windows")
let _unused : Unit = {
  ignore(@c_buffer.Buffer::strlen)
  ignore(@bytes_util.ascii_to_string)
  ignore(@utf8.encode(""))
}
