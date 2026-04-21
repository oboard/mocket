///|
#owned(url, http_method_c, body, headers, timeout_ms)
extern "c" fn fetch_ffi(
  url : Bytes,
  http_method_c : Bytes,
  body : Bytes,
  headers : Bytes,
  timeout_ms : Int,
) -> Int = "mocket_fetch"

///|
extern "c" fn fetch_status_ffi() -> Int = "mocket_fetch_status"

///|
extern "c" fn fetch_headers_ffi() -> Bytes = "mocket_fetch_headers"

///|
extern "c" fn fetch_error_ffi() -> Bytes = "mocket_fetch_error"

///|
extern "c" fn fetch_body_len_ffi() -> Int = "mocket_fetch_body_len"

///|
#owned(dst, max_len)
extern "c" fn fetch_body_copy_ffi(dst : Bytes, max_len : Int) -> Int = "mocket_fetch_body_copy"

///|
fn headers_to_lines(headers : Map[String, String]) -> String {
  let buf = @buffer.new()
  headers.each(fn(k, v) {
    buf.write_string(k)
    buf.write_string(": ")
    buf.write_string(v)
    buf.write_string("\r\n")
  })
  buf.to_string()
}

///|
fn parse_headers_native(headers_text : String) -> Map[StringView, StringView] {
  let headers : Map[StringView, StringView] = {}
  headers_text
  .split("\n")
  .each(line => {
    let line = line.trim()
    if line != "" {
      if line.find(":") is Some(idx) {
        let key = line[:idx].trim()
        let value = line[idx + 1:].trim()
        if key != "" {
          headers.set(key, value)
        }
      }
    }
  })
  headers
}

///|
fn fetch_body_native() -> Bytes {
  let body_len = fetch_body_len_ffi()
  if body_len <= 0 {
    return b""
  }
  let arr = Array::make(body_len, b'\x00')
  let buf = Bytes::from_array(arr)
  let copied_len = fetch_body_copy_ffi(buf, body_len)
  buf[:copied_len].to_bytes()
}

///|
priv struct NativeFetchResult {
  status_code : Int
  headers : Map[StringView, StringView]
  body : Bytes
}

///|
pub async fn fetch(
  url : String,
  body? : String,
  http_method : HttpMethod,
  data? : &Responder,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise Error {
  ignore(credentials)
  ignore(mode)
  let (req_body, req_headers) = prepare_fetch_payload(body, data, headers)
  let method_str = http_method.to_string()
  let body_str = req_body.unwrap_or("")
  let headers_str = headers_to_lines(req_headers)
  let result : NativeFetchResult = suspend(fn(ok_cb, reject) {
    let ret = fetch_ffi(
      to_cbytes(url),
      to_cbytes(method_str),
      to_cbytes(body_str),
      to_cbytes(headers_str),
      30000,
    )
    if ret != 0 {
      reject(FetchError::RequestFailed(from_cbytes(fetch_error_ffi())))
      return
    }
    ok_cb({
      status_code: fetch_status_ffi(),
      headers: parse_headers_native(from_cbytes(fetch_headers_ffi())),
      body: fetch_body_native(),
    })
  })
  HttpResponse::new(
    StatusCode::from_int(result.status_code),
    headers=result.headers,
    raw_body=result.body,
  )
}
