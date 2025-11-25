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
