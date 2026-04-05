///|
async fn main {
  let server = @http.Server::new(
    @socket.Addr::parse("0.0.0.0:3004"),
    reuse_addr=true,
  )
  println("Raw async server listening on port 3004")
  server.run_forever((request, _body, conn) => {
    conn.send_response(200, "OK", extra_headers={ "Content-Type": "text/plain" })
    conn.write("Hello, World!")
    conn.end_response()
  })
}
