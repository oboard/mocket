///|
priv struct ContentType {
  media_type : StringView
  subtype : StringView
  params : Map[StringView, StringView]
} derive(Show)

///|
fn parse_content_type(s : StringView) -> ContentType? {
  fn dequote(value : StringView) -> StringView {
    if value is ['"', .. rest, '"'] {
      rest
    } else {
      value
    }
  }

  let params = Map::new()
  let (media_type, subtype, rest) = lexmatch s with longest {
    (
      "[ \t]*"
      ("[^ \t/;=]+" as media_type)
      "[ \t]*"
      "/"
      "[ \t]*"
      ("[^ \t/;=]+" as subtype)
      "[ \t]*",
      rest
    ) => (media_type, subtype, rest)
    _ => return None
  }

  for curr = rest {
    lexmatch curr with longest {
      ("[ \t]+", rest) => continue rest
      (
        ";"
        "[ \t]*"
        ("[^ \t=;]+" as key)
        "[ \t]*"
        "="
        "[ \t]*"
        ("(\"[^\"]*\"|[^ \t;]*)" as value)
        "[ \t]*",
        rest
      ) => {
        params.set(key, dequote(value))
        continue rest
      }
      (";" "[ \t]*", rest) => continue rest
      "" => break
      _ => break
    }
  }

  Some({ media_type, subtype, params })
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
test "parse_content_type_with_quoted_params" {
  inspect(
    parse_content_type(
      "multipart/form-data; boundary=\"foo;bar\"; charset = utf-8",
    ),
    content=(
      #|Some({media_type: "multipart", subtype: "form-data", params: {"boundary": "foo;bar", "charset": "utf-8"}})
    ),
  )
}

///|
test "parse_content_type_invalid" {
  inspect(
    parse_content_type("application"),
    content=(
      #|None
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
