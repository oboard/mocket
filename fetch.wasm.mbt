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
  ignore(body)
  ignore(http_method)
  ignore(data)
  ignore(headers)
  ignore(credentials)
  ignore(mode)
  raise FetchError::RequestFailed("fetch is not implemented on wasm target")
}
