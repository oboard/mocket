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
  ignore(url)
  ignore(http_method)
  ignore(credentials)
  ignore(mode)
  ignore(body)
  ignore(data)
  ignore(headers)
  ignore(prepare_fetch_payload)
  suspend(fn(_ok_cb, reject) {
    reject(FetchError::RequestFailed("fetch is not implemented on wasm target"))
  })
}
