// Example usage of mocket package in MoonBit

fn main {
  let server = @mocket.listen(get_context(), 4000)
  // readFile example  
  // @mocket.readFile("./logo.jpg").finally(
  //   fn(data : Bytes) { println(data.length()) },
  // )
  // html response example
  server.get(
    "/",
    fn(_req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
      @mocket.html("<h1>Hello, World!</h1>")
    },
  )
  // string response example
  server.get(
    "/text",
    fn(_req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
      String("<h1>Hello, World!</h1>")
    },
  )
  // json data example
  server.get(
    "/data",
    fn(_req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
      { "name": "John Doe", "age": 30, "city": "New York" }
    },
  )
  // echo server example
  server.post(
    "/echo",
    fn(req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
      match req.body {
        Some(data) => data
        _ => String("No data received")
      }
    },
  )
  // file serving example
  server.get(
    "/image",
    fn(_req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
      @mocket.file("logo.jpg")
    },
  )

  // static file serving example
  fn staticMap(files : @json.JsonValue) {
    match files {
      Array(array) => array.each(staticMap)
      String(path) =>
        server.get(
          "/" + path,
          fn(req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
            match req.path {
              Some(path) => @mocket.file("./" + path)
              _ => @mocket.file("index.html")
            }
          },
        )
      _ => ()
    }
  }

  // readDir example  
  @mocket.readDir("./").then(println).finally(staticMap)
}
