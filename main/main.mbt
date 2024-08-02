// Example usage of mocket package in MoonBit

fn main {
  let server = @mocket.listen(get_context(), 4000)
  // html response example
  server.get("/", fn(_req, _res) { @mocket.html("<h1>Hello, World!</h1>") })
  // string response example
  server.get("/text", fn(_req, _res) { String("<h1>Hello, World!</h1>") })
  // json data example
  server.get(
    "/data",
    fn(_req, _res) { { "name": "John Doe", "age": 30, "city": "New York" } },
  )
  // echo server example
  server.post(
    "/echo",
    fn(req, _res) {
      match req {
        { "body": data } => data
        _ => String("No data received")
      }
    },
  )
  // file serving example
  server.get("/image", fn(_req, _res) { @mocket.file("logo.png") })
}
