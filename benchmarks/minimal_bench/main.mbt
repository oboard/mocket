///|
async fn main {
  let server = @http.Server::new(
    @socket.Addr::parse("0.0.0.0:3005"),
    reuse_addr=true,
  )
  println("Minimal MoonBit server on port 3005")
  server.run_forever((_request, _body, conn) => {
    conn.send_response(200, "OK")
  })
}
