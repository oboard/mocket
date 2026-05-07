///|
priv struct ContentType {
  media_type : StringView
  subtype : StringView
  params : Map[StringView, StringView]
}

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
  let ct = parse_content_type("application/json; charset=utf-8")
  assert_true(ct is Some(_))
  guard ct is Some(found) else { panic() }
  @test.assert_eq(found.media_type, "application")
  @test.assert_eq(found.subtype, "json")
  @test.assert_eq(found.params.get("charset"), Some("utf-8"))
}

///|
test "parse_content_type_with_quoted_params" {
  let ct = parse_content_type(
    "multipart/form-data; boundary=\"foo;bar\"; charset = utf-8",
  )
  assert_true(ct is Some(_))
  guard ct is Some(found) else { panic() }
  @test.assert_eq(found.media_type, "multipart")
  @test.assert_eq(found.subtype, "form-data")
  @test.assert_eq(found.params.get("boundary"), Some("foo;bar"))
  @test.assert_eq(found.params.get("charset"), Some("utf-8"))
}

///|
test "parse_content_type_invalid" {
  assert_true(parse_content_type("application") is None)
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
