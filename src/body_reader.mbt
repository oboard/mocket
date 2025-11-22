///|
pub suberror BodyError {
  InvalidJsonCharset
  InvalidJson
  InvalidText
}

///|
fn read_body(
  req_headers : Map[StringView, StringView],
  body_bytes : BytesView,
) -> HttpBody raise BodyError {
  let content_type = req_headers.get("Content-Type")
  if content_type is Some(content_type) {
    let content_type = parse_content_type(content_type)
    if content_type is Some(content_type) {
      return match content_type {
        { subtype: "json", .. } => {
          let json = @encoding/utf8.decode(body_bytes) catch {
            _ => raise BodyError::InvalidJsonCharset
          }
          Json(@json.parse(json) catch { _ => raise BodyError::InvalidJson })
        }
        { media_type: "text", .. } =>
          Text(
            @encoding/utf8.decode(body_bytes) catch {
              _ => raise BodyError::InvalidText
            },
          )
        { subtype: "x-www-form-urlencoded", .. } =>
          Form(parse_form_data(body_bytes))
        { subtype: "form-data" | "multipart", params, .. } => {
          let boundary = match params.get("boundary") {
            Some(b) => Some(b)
            None => params.get("BOUNDARY")
          }
          match boundary {
            Some(b) => Multipart(parse_multipart(body_bytes, b.to_string()))
            None => Bytes(body_bytes)
          }
        }
        _ => Bytes(body_bytes)
      }
    }
  }
  Bytes(body_bytes)
}

///|
priv struct ContentType {
  media_type : StringView
  subtype : StringView
  params : Map[StringView, StringView]
} derive(Show)

///|
fn parse_content_type(s : StringView) -> ContentType? {
  let parts = s.split(";").to_array()
  if parts.is_empty() {
    None
  } else {
    let main_part_str = parts[0].trim_space()
    let media_type_parts = main_part_str.split("/").to_array()
    if media_type_parts.length() != 2 {
      None
    } else {
      let media_type = media_type_parts[0].trim_space()
      let subtype = media_type_parts[1].trim_space()
      let params = {}
      for i in 1..<parts.length() {
        let param_part = parts[i].trim_space()
        let eq_index = param_part.find("=")
        try {
          match eq_index {
            Some(idx) => {
              let key = param_part[0:idx].trim_space()
              let value = param_part[idx + 1:].trim_space()
              params[key] = value
            }
            None => () // Ignore malformed parameters
          }
        } catch {
          _ => ()
        }
      }
      Some({ media_type, subtype, params })
    }
  }
}

///|
test "parse_content_type" {
  inspect(
    parse_content_type("application/json; charset=utf-8"),
    content=(
      #|Some({media_type: "application", subtype: "json", params: {"charset": "utf-8"}})
    ),
  )
}

///|
test "parse_form_data" {
  inspect(
    parse_form_data(b"name=John+Doe&age=30"),
    content=(
      #|{"name": "John Doe", "age": "30"}
    ),
  )
}
