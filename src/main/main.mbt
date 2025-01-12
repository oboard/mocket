// Example usage of mocket package in MoonBit

// `run_async` spawn a new coroutine and execute an async function in it
///|
fn run_async(f :  async() -> Unit) -> Unit = "%async.run"

// `suspend` will suspend the execution of the current coroutine.
// The suspension will be handled by a callback passed to `suspend`
///|
// async fn suspend[T, E : Error](
//   // `f` is a callback for handling suspension
//   // the first parameter of `f` is used to resume the execution of the coroutine normally
//   // the second parameter of `f` is used to cancel the execution of the current coroutine
//   // by throwing an error at suspension point
//   f : ((T) -> Unit, (E) -> Unit) -> Unit
// ) -> T!E = "%async.suspend"

///|
fn main {
  println("Starting server...")
  let port = 4000
  let server = @mocket.listen(get_context(), port)
  listen_event("echo", fn(json) { println(json) })

  // 修改文件读取示例
  // try {
  //   let data = @mocket.readFile!!("./logo.jpg")
  //   println(data.length())
  // } catch {
  //   err => println("Error reading file: \{err}")
  // }

  server.get("/", fn(_req : @mocket.HttpRequest, _res : @mocket.HttpResponse) {
    @mocket.html("<h1>Hello, World!</h1>")
  })
  // string response example
  server.get("/text", fn(
    _req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    String("<h1>Hello, World!</h1>")
  })
  // async json data example
  server.get("/async_data", async fn(
    _req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    { "name": "John Doe", "age": 30, "city": "New York" }
  })
  // json data example
  server.get("/data", fn(
    _req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    { "name": "John Doe", "age": 30, "city": "New York" }
  })
  // echo server example
  server.post("/echo", fn(
    req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    match req.body {
      Some(data) => data
      _ => String("No data received")
    }
  })
  // file serving example
  server.get("/image", fn(
    _req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    @mocket.file("logo.jpg")
  })

  // buffer serving example
  server.get("/buffer", fn(
    _req : @mocket.HttpRequest,
    _res : @mocket.HttpResponse
  ) {
    @mocket.buffer(
      [
        72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33, 32, 84, 104, 105,
        115, 32, 105, 115, 32, 97, 32, 116, 101, 115, 116, 32, 115, 116, 114, 105,
        110, 103, 32, 102, 111, 114, 32, 116, 101, 115, 116, 105, 110, 103, 32, 112,
        117, 114, 112, 111, 115, 101,
      ].map(fn(x) { x.to_byte() })
      |> Bytes::from_array,
    )
  })

  // static file serving example
  // Example: http://localhost:4000/static/logo.jpg => ./logo.jpg
  server.resource("/static/", "./")
  
  run_async(fn() {
    try {
      let result = @mocket.exec!!("ls")
      println(result)
    } catch {
      err => println("Error executing command: \{err}")
    }
  })
  run_async(fn() {
    try {
      let response = @mocket.fetch!!("https://api64.ipify.org/")
      println(response)
    } catch {
      err => println("Error fetching data: \{err}")
    }
  })
}
