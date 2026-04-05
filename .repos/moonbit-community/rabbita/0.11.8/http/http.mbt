///|
using @cmd {type Cmd}

///|
#cfg(target="js")
pub(all) enum Expecting[Msg, Model] {
  Json((Result[Model, String]) -> Msg, (Json) -> Result[Model, String])
  Text((Result[String, String]) -> Msg)
}

///|
#cfg(target="js")
pub(all) enum Body {
  Json(Json)
  Text(String)
  Empty
}

///|
#cfg(target="js")
fn Body::content_type(self : Body) -> String {
  match self {
    Json(_) => "application/json"
    Text(_) => "text/plain"
    Empty(_) => "text/plain"
  }
}

///|
#cfg(target="js")
fn Body::stringfiy(self : Body) -> String {
  match self {
    Json(json) => json.stringify()
    Text(text) => text
    Empty => ""
  }
}

///|
#cfg(target="js")
extern "js" fn js_request(
  url : String,
  http_method : String,
  content_type~ : String,
  body~ : String,
  has_body~ : Bool,
  succeed~ : (String) -> Unit,
  failed~ : (String) -> Unit,
) =
  #| (url,method,contentType,body,hasBody,succeed,failed) => {
  #|   var config = { method: method, headers: { 'Content-Type': contentType } }; 
  #|   if (hasBody) { config.body = body };
  #|   fetch(url, config)
  #|     .then(response => response.text())
  #|     .then(json => succeed(json))
  #|     .catch(error => {
  #|       failed(error.toString())
  #|     })
  #| }

///|
#cfg(target="js")
fn[Model] request(
  url : String,
  http_method : String,
  expect~ : Expecting[Cmd, Model],
  body~ : Body,
) -> Cmd {
  let launch = fn(scheduler : @cmd.Scheduler) {
    let has_body = match body {
      Empty => false
      _ => true
    }
    let content_type = body.content_type()
    let body = body.stringfiy()
    match expect {
      Json(f, decoder) =>
        js_request(
          url,
          http_method,
          has_body~,
          body~,
          content_type~,
          succeed=str => {
            let result = Ok(@json.parse(str)) catch {
              _ => Err("Json parse error")
            }
            scheduler.add(f(result.bind(decoder)))
          },
          failed=msg => scheduler.add(f(Err("Http request failed:\{msg}"))),
        )
      Text(f) =>
        js_request(
          url,
          http_method,
          has_body~,
          body~,
          content_type~,
          succeed=str => scheduler.add(f(Ok(str))),
          failed=msg => scheduler.add(f(Err("Http request failed:\{msg}"))),
        )
    }
  }
  @cmd.custom_cmd(kind=Immediately, launch)
}

///|
/// Create a command to send a GET request.
#cfg(target="js")
pub fn[Model] get(url : String, expect~ : Expecting[Cmd, Model]) -> Cmd {
  request(url, "GET", expect~, body=Empty)
}

///|
/// Create a command to send a PUT request.
#cfg(target="js")
pub fn[Model] delete(url : String, expect~ : Expecting[Cmd, Model]) -> Cmd {
  request(url, "DELETE", expect~, body=Empty)
}

///|
/// Create a command to send a POST request.
#cfg(target="js")
pub fn[Model] post(
  url : String,
  body : Body,
  expect~ : Expecting[Cmd, Model],
) -> Cmd {
  request(url, "POST", body~, expect~)
}

///|
/// Create a command to send a PATCH request.
#cfg(target="js")
pub fn[Model] patch(
  url : String,
  body : Body,
  expect~ : Expecting[Cmd, Model],
) -> Cmd {
  request(url, "PATCH", body~, expect~)
}
