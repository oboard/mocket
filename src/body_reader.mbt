///|
pub suberror BodyError {
  InvalidJsonCharset
  InvalidJson
  InvalidText
}

///|
fn read_body(
  req_headers : Map[String, String],
  body_bytes : @moonbitlang/core/bytes.View,
) -> HttpBody raise BodyError {
  let content_type = req_headers.get("Content-Type")
  match content_type {
    Some([.. "application/json", ..]) => {
      let json = @encoding.decoder(UTF8).decode(body_bytes) catch {
        _ => raise BodyError::InvalidJsonCharset
      }
      Json(@json.parse(json) catch { _ => raise BodyError::InvalidJson })
    }
    Some([.. "text/plain", ..] | [.. "text/html", ..]) =>
      Text(
        @encoding.decoder(UTF8).decode(body_bytes) catch {
          _ => raise BodyError::InvalidText
        },
      )
    _ => Bytes(body_bytes)
  }
}
