///|
pub fn html(body : String) -> Json {
  { "__": "text/html;charset=UTF-8", "body": body }
}

///|
pub fn json(body : Json) -> Json {
  { "__": "application/json;charset=UTF-8", "body": body }
}

///|
pub fn text(body : String) -> Json {
  { "__": "text/plain;charset=UTF-8", "body": body }
}
