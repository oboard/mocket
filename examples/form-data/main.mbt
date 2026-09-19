///|
using @mocket {type FormData, type HttpResponse}

///|
async fn main {
  let app = @mocket.new(max_body_size=10 * 1024 * 1024)

  // Submit an HTML form with `enctype="multipart/form-data"` to this route.
  app.post("/upload", event => {
    let form : FormData = event.body()
    if form is { "file": { filename, content_type, data, }, .. } {
      let content =
        $|filename: \{filename.unwrap_or("Unknown")}
        $|content_type: \{content_type.unwrap_or("Unknown")}
        $|size: \{data.length()} bytes
      HttpResponse(OK).body(content)
    } else {
      HttpResponse(BadRequest).body("missing file field")
    }
  })

  // A minimal browser form for trying the upload endpoint.
  app.get("/", _ => {
    @mocket.html(
      (
        #|<!doctype html>
        #|<html>
        #|  <body>
        #|    <form action="/upload" method="post" enctype="multipart/form-data">
        #|      <label>File <input type="file" name="file" required></label>
        #|      <button type="submit">Upload</button>
        #|    </form>
        #|  </body>
        #|</html>
      ),
    )
  })

  println("Open http://localhost:4000 and choose a file to upload.")
  app.listen("0.0.0.0:4000")
}
