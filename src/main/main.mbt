///|
fn main {
  let app = @mocket.new()
  app.get("/", _event => "⚡️ Tadaa!")
  app.get("/json", _event => {
    "name": "John Doe",
    "age": 30,
    "city": "New York",
  })
  app.post("/echo", _event => _event.req.body.to_json())
  app.serve(port=4000)
  println("Server started on port 4000")

  // let server = @mocket.listen(get_context(), port)
  // listen_event("echo", fn(json) { println(json) })

  // // 修改文件读取示例
  // // try {
  // //   let data = @mocket.readFile!("./logo.jpg")
  // //   println(data.length())
  // // } catch {
  // //   err => println("Error reading file: \{err}")
  // // }
  // run_async(fn() {
  //   server.get("/", fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     @mocket.html("<h1>Hello, World!</h1>")
  //   })
  //   // string response example
  //   server.get("/text", fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     Json::string("<h1>Hello, World!</h1>")
  //   })
  //   // async json data example
  //   server.get("/async_data", async fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     { "name": "John Doe", "age": 30, "city": "New York" }
  //   })
  //   // json data example
  //   server.get("/data", fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     { "name": "John Doe", "age": 30, "city": "New York" }
  //   })
  //   // echo server example
  //   server.post("/echo", fn(
  //     req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     match req.body {
  //       Some(data) => data
  //       _ => Json::string("No data received")
  //     }
  //   })
  //   // file serving example
  //   server.get("/image", fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     @mocket.file("logo.jpg")
  //   })

  //   // buffer serving example
  //   server.get("/buffer", fn(
  //     _req : @mocket.HttpRequest,
  //     _res : @mocket.HttpResponse
  //   ) {
  //     @mocket.buffer(
  //       [
  //         72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33, 32, 84, 104, 105,
  //         115, 32, 105, 115, 32, 97, 32, 116, 101, 115, 116, 32, 115, 116, 114, 105,
  //         110, 103, 32, 102, 111, 114, 32, 116, 101, 115, 116, 105, 110, 103, 32,
  //         112, 117, 114, 112, 111, 115, 101,
  //       ].map(fn(x) { x.to_byte() })
  //       |> Bytes::from_array,
  //     )
  //   })

  //   // static file serving example
  //   // Example: http://localhost:4000/static/logo.jpg => ./logo.jpg
  //   server.resource("/static/", "./")
  //   try {
  //     let result = @mocket.exec("ls")
  //     println(result)
  //   } catch {
  //     err => println("Error executing command: \{err}")
  //   }
  // })
}
