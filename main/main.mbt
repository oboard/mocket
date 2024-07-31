// Example usage of mocket package in MoonBit

fn main {
  let server = @mocket.listen(get_context(), 4000)
  server.get("/", fn(_req, _res) { @mocket.html("<h1>Hello, World!</h1>") })
  server.get("/text", fn(_req, _res) { String("<h1>Hello, World!</h1>") })
  server.get(
    "/data",
    fn(_req, _res) { { "name": "John Doe", "age": 30, "city": "New York" } },
  )
  server.post(
    "/echo",
    fn(req, _res) {
      match req {
        { "body": data } => data
        _ => String("No data received")
      }
    },
  )
}
