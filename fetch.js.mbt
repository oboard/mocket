///|
extern "js" fn fetch_ffi(url : String, options : @js.Value) -> @js.Promise =
  #| (url, options) => fetch(url, options)

///|
extern "js" fn fetch_response_status(resp : @js.Value) -> Int =
  #| (resp) => resp.status

///|
extern "js" fn fetch_response_bytes(resp : @js.Value) -> @js.Promise =
  #| async (resp) => {
  #|   const ab = await resp.arrayBuffer();
  #|   return Array.from(new Uint8Array(ab));
  #| }

///|
extern "js" fn fetch_response_headers_json(resp : @js.Value) -> String =
  #| (resp) => {
  #|   const out = {};
  #|   resp.headers.forEach((value, key) => {
  #|     out[key] = value;
  #|   });
  #|   return JSON.stringify(out);
  #| }

///|
fn parse_headers_json(
  json_str : String,
) -> Map[StringView, StringView] raise Error {
  let headers : Map[StringView, StringView] = {}
  match @json.parse(json_str) {
    Object(obj) => {
      obj.each(fn(k, v) { if v is String(s) { headers.set(k, s) } })
      headers
    }
    _ =>
      raise FetchError::RequestFailed("response headers is not a JSON object")
  }
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
  let (req_body, req_headers) = prepare_fetch_payload(body, data, headers)
  let options = @js.Object::new()
  options["method"] = http_method.to_string()
  if req_body is Some(body_str) {
    options["body"] = body_str
  }
  if not(req_headers.is_empty()) {
    let headers_obj = @js.Object::new()
    req_headers.each(fn(k, v) { headers_obj[k] = v })
    options["headers"] = headers_obj.to_value()
  }
  ignore(credentials)
  ignore(mode)

  let resp = fetch_ffi(url, options.to_value()).wait() catch {
    e => raise FetchError::RequestFailed("js fetch failed: \{e}")
  }
  let status = fetch_response_status(resp)
  let body_arr : Array[Byte] = fetch_response_bytes(resp).wait().cast() catch {
      e => raise FetchError::RequestFailed("read response body failed: \{e}")
    }
  let response_headers = parse_headers_json(fetch_response_headers_json(resp))

  HttpResponse::new(
    StatusCode::from_int(status),
    headers=response_headers,
    raw_body=Bytes::from_array(body_arr),
  )
}
